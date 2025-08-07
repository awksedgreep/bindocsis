defmodule Bindocsis.HumanConfig do
  @moduledoc """
  Human-friendly configuration parser for bidirectional JSON/YAML support.

  Enables users to create and edit DOCSIS configurations using intuitive
  YAML/JSON files with human-readable values like "591 MHz", "192.168.1.100",
  and "enabled" that automatically convert to/from binary DOCSIS formats.

  ## Features

  - **Bidirectional conversion**: Binary ↔ Human-readable YAML/JSON
  - **Smart value parsing**: Accepts "591 MHz", "100 Mbps", "enabled", etc.
  - **Intelligent field mapping**: Uses TLV names and types for proper parsing
  - **Validation and error handling**: DOCSIS compliance checking
  - **Round-trip integrity**: Ensures binary → YAML → binary consistency
  - **Template support**: Generate starting configurations for common scenarios

  ## Example Usage

  Convert binary configurations to human-readable formats and back:

      # Binary config to YAML
      binary_config = <<1, 4, 35, 57, 241, 192, 255>>
      {:ok, yaml_string} = Bindocsis.HumanConfig.to_yaml(binary_config)

      # YAML back to binary
      {:ok, binary_config} = Bindocsis.HumanConfig.from_yaml(yaml_string)

      # Binary config to JSON
      {:ok, json_string} = Bindocsis.HumanConfig.to_json(binary_config)

      # JSON back to binary
      {:ok, binary_config} = Bindocsis.HumanConfig.from_json(json_string)
  """

  alias Bindocsis.ValueFormatter
  alias Bindocsis.ValueParser
  alias Bindocsis.DocsisSpecs

  @type human_config :: %{
          docsis_version: String.t(),
          tlvs: [human_tlv()],
          metadata: map()
        }

  @type human_tlv :: %{
          type: non_neg_integer(),
          name: String.t(),
          value: String.t() | map() | list(),
          description: String.t() | nil,
          raw_value: any() | nil
        }

  @type binary_config :: binary()
  @type parse_options :: [
          docsis_version: String.t(),
          include_metadata: boolean(),
          include_descriptions: boolean(),
          format_style: :compact | :verbose,
          validate: boolean()
        ]

  @doc """
  Converts a binary DOCSIS configuration to human-readable YAML format.

  ## Parameters

  - `binary_config` - Binary DOCSIS configuration data
  - `opts` - Conversion options

  ## Options

  - `:docsis_version` - DOCSIS version for metadata (default: "3.1")
  - `:include_metadata` - Include configuration metadata (default: true)
  - `:include_descriptions` - Include TLV descriptions (default: false)
  - `:format_style` - :compact or :verbose formatting (default: :compact)
  - `:validate` - Validate configuration consistency (default: true)

  ## Returns

  - `{:ok, yaml_string}` - Successfully converted YAML configuration
  - `{:error, reason}` - Conversion error with reason

  ## Example

      iex> binary = <<1, 4, 35, 57, 241, 192, 255>>
      iex> {:ok, yaml} = Bindocsis.HumanConfig.to_yaml(binary)
      iex> String.contains?(yaml, "591 MHz")
      true
  """
  @spec to_yaml(binary_config(), parse_options()) :: {:ok, String.t()} | {:error, String.t()}
  def to_yaml(binary_config, opts \\ []) do
    with {:ok, human_config} <- binary_to_human(binary_config, opts) do
      yaml_string = generate_yaml(human_config, opts)
      {:ok, yaml_string}
    else
      {:error, _reason} = error -> error
    end
  end

  @doc """
  Converts a binary DOCSIS configuration to human-readable JSON format.

  Similar to `to_yaml/2` but outputs JSON format.
  """
  @spec to_json(binary_config(), parse_options()) :: {:ok, String.t()} | {:error, String.t()}
  def to_json(binary_config, opts \\ []) do
    with {:ok, human_config} <- binary_to_human(binary_config, opts) do
      try do
        json_string = JSON.encode!(human_config)
        {:ok, json_string}
      rescue
        e -> {:error, "JSON encoding failed: #{Exception.message(e)}"}
      end
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Parses a human-readable YAML configuration to binary DOCSIS format.

  ## Parameters

  - `yaml_string` - YAML configuration string
  - `opts` - Parsing options

  ## Options

  - `:validate` - Validate parsed configuration (default: true)
  - `:docsis_version` - Target DOCSIS version (default: "3.1")
  - `:strict` - Enable strict parsing mode (default: false)

  ## Returns

  - `{:ok, binary_config}` - Successfully parsed binary configuration
  - `{:error, reason}` - Parsing error with reason

  ## Example

      iex> yaml = \"\"\"
      ...> docsis_version: "3.1"
      ...> tlvs:
      ...>   - type: 1
      ...>     name: "Downstream Frequency"
      ...>     formatted_value: "591 MHz"
      ...> \"\"\"
      iex> {:ok, _binary} = Bindocsis.HumanConfig.from_yaml(yaml)
  """
  @spec from_yaml(String.t(), parse_options()) :: {:ok, binary_config()} | {:error, String.t()}
  def from_yaml(yaml_string, opts \\ []) do
    case YamlElixir.read_from_string(yaml_string) do
      {:ok, parsed_yaml} ->
        human_to_binary(parsed_yaml, opts)

      {:error, error} ->
        error_msg =
          case error do
            %{__struct__: module}
            when module in [YamlElixir.ParsingError, YamlElixir.ScanningError] ->
              Exception.message(error)

            _ ->
              inspect(error)
          end

        {:error, "YAML parsing failed: #{error_msg}"}
    end
  end

  @doc """
  Parses a human-readable JSON configuration to binary DOCSIS format.

  Similar to `from_yaml/2` but accepts JSON format.
  """
  @spec from_json(String.t(), parse_options()) :: {:ok, binary_config()} | {:error, String.t()}
  def from_json(json_string, opts \\ []) do
    case JSON.decode(json_string) do
      {:ok, parsed_json} ->
        human_to_binary(parsed_json, opts)

      {:error, error} ->
        {:error, "JSON parsing failed: #{inspect(error)}"}
    end
  end

  @doc """
  Validates round-trip conversion integrity (binary → human → binary).

  Ensures that converting a binary configuration to human-readable format
  and back results in the same binary data.
  """
  @spec validate_round_trip(binary_config(), parse_options()) ::
          {:ok, :valid} | {:error, String.t()}
  def validate_round_trip(binary_config, opts \\ []) do
    with {:ok, human_config} <- binary_to_human(binary_config, opts),
         {:ok, reconverted_binary} <- human_to_binary(human_config, opts) do
      if binary_config == reconverted_binary do
        {:ok, :valid}
      else
        {:error, "Round-trip validation failed: binary data differs after conversion"}
      end
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Generates a human-readable configuration template for a given scenario.

  ## Parameters

  - `template_type` - Type of template (:residential, :business, :minimal, etc.)
  - `opts` - Template generation options

  ## Template Types

  - `:residential` - Standard residential cable modem configuration
  - `:business` - Business-grade configuration with enhanced features
  - `:minimal` - Minimal working configuration for testing
  - `:gigabit` - High-speed gigabit service configuration
  - `:ipv6` - IPv6-enabled configuration

  ## Example

      iex> {:ok, yaml} = Bindocsis.HumanConfig.generate_template(:residential)
      iex> String.contains?(yaml, "591 MHz") and String.contains?(yaml, "enabled")
      true
  """
  @spec generate_template(atom(), parse_options()) :: {:ok, String.t()} | {:error, String.t()}
  def generate_template(template_type, opts \\ []) do
    case create_template_config(template_type, opts) do
      {:ok, template_config} ->
        docsis_version = Keyword.get(opts, :docsis_version, "3.1")
        include_descriptions = Keyword.get(opts, :include_descriptions, true)

        human_config = %{
          "docsis_version" => docsis_version,
          "tlvs" => template_config,
          "metadata" => %{
            "template_type" => Atom.to_string(template_type),
            "generated_at" => DateTime.utc_now() |> DateTime.to_iso8601(),
            "description" => get_template_description(template_type)
          }
        }

        yaml_string = generate_yaml(human_config, include_descriptions: include_descriptions)
        {:ok, yaml_string}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # Private helper functions

  @spec binary_to_human(binary_config(), parse_options()) ::
          {:ok, human_config()} | {:error, String.t()}
  defp binary_to_human(binary_config, opts) when is_binary(binary_config) do
    docsis_version = Keyword.get(opts, :docsis_version, "3.1")
    include_metadata = Keyword.get(opts, :include_metadata, true)
    include_descriptions = Keyword.get(opts, :include_descriptions, false)

    case Bindocsis.parse(binary_config,
           format: :binary,
           enhanced: true,
           docsis_version: docsis_version
         ) do
      {:ok, enhanced_tlvs} when is_list(enhanced_tlvs) ->
        human_tlvs =
          Enum.map(enhanced_tlvs, fn tlv ->
            formatted_val = Map.get(tlv, :formatted_value) || format_raw_value(tlv.value_type, tlv.value)

            base_tlv = %{
              "type" => tlv.type,
              "name" => tlv.name,
              "formatted_value" => formatted_val,
              "value_type" => Atom.to_string(tlv.value_type)
            }

            base_tlv =
              if tlv.raw_value do
                # Convert tuples and other complex types to JSON-friendly formats
                serializable_raw = make_json_serializable(tlv.raw_value)
                Map.put(base_tlv, "raw_value", serializable_raw)
              else
                base_tlv
              end

            # Include subtlvs for compound TLVs (but NOT for hex_string TLVs per CLAUDE.md)
            base_tlv =
              if Map.has_key?(tlv, :subtlvs) and is_list(tlv.subtlvs) and length(tlv.subtlvs) > 0 and tlv.value_type != :hex_string do
                # Recursively process subtlvs - they should also be enriched TLVs
                human_subtlvs = Enum.map(tlv.subtlvs, fn subtlv ->
                  sub_formatted_val = Map.get(subtlv, :formatted_value) || format_raw_value(subtlv.value_type, subtlv.value)
                  
                  sub_base_tlv = %{
                    "type" => subtlv.type,
                    "name" => subtlv.name,
                    "formatted_value" => sub_formatted_val,
                    "value_type" => Atom.to_string(subtlv.value_type)
                  }
                  
                  # Recursively include sub-subtlvs if they exist
                  if Map.has_key?(subtlv, :subtlvs) and is_list(subtlv.subtlvs) and length(subtlv.subtlvs) > 0 do
                    # This could go deeper, but for now handle 2-level nesting
                    Map.put(sub_base_tlv, "subtlvs", subtlv.subtlvs)
                  else
                    sub_base_tlv
                  end
                end)
                
                Map.put(base_tlv, "subtlvs", human_subtlvs)
              else
                base_tlv
              end

            if include_descriptions and tlv.description do
              Map.put(base_tlv, "description", tlv.description)
            else
              base_tlv
            end
          end)

        human_config = %{
          "docsis_version" => docsis_version,
          "tlvs" => human_tlvs
        }

        human_config =
          if include_metadata do
            Map.put(human_config, "metadata", %{
              "total_tlvs" => length(human_tlvs),
              "parsed_at" => DateTime.utc_now() |> DateTime.to_iso8601(),
              "binary_size" => byte_size(binary_config)
            })
          else
            human_config
          end

        {:ok, human_config}

      {:error, reason} ->
        {:error, "Failed to parse binary configuration: #{inspect(reason)}"}
    end
  end

  @spec human_to_binary(map(), parse_options()) :: {:ok, binary_config()} | {:error, String.t()}
  defp human_to_binary(human_config, opts) do
    validate = Keyword.get(opts, :validate, true)
    docsis_version = Keyword.get(opts, :docsis_version, "3.1")

    case extract_tlvs_from_human_config(human_config) do
      {:ok, human_tlvs} ->
        with {:ok, binary_tlvs} <- convert_human_tlvs_to_binary(human_tlvs, docsis_version),
             {:ok, binary_config} <- generate_binary_config(binary_tlvs) do
          if validate do
            case validate_binary_config(binary_config, docsis_version) do
              {:ok, _} -> {:ok, binary_config}
              {:error, reason} -> {:error, "Validation failed: #{reason}"}
            end
          else
            {:ok, binary_config}
          end
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp extract_tlvs_from_human_config(human_config) do
    case human_config do
      %{"tlvs" => tlvs} when is_list(tlvs) ->
        {:ok, tlvs}

      %{} ->
        {:error, "Configuration must contain 'tlvs' array"}

      _ ->
        {:error, "Invalid configuration format"}
    end
  end

  defp convert_human_tlvs_to_binary(human_tlvs, docsis_version) do
    results = Enum.map(human_tlvs, &convert_human_tlv_to_binary(&1, docsis_version))

    case Enum.find(results, fn result -> match?({:error, _}, result) end) do
      nil ->
        binary_tlvs = Enum.map(results, fn {:ok, tlv} -> tlv end)
        {:ok, binary_tlvs}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp convert_human_tlv_to_binary(human_tlv, docsis_version) do
    with {:ok, type} <- extract_tlv_type(human_tlv),
         {:ok, value_type} <- get_tlv_value_type(type, docsis_version, human_tlv) do
      
      # CRITICAL: If value_type is :hex_string, treat as opaque binary data
      # Do NOT attempt to process subtlvs (per CLAUDE.md guidance)
      if value_type == :hex_string do
        # Convert as simple TLV using hex_string parser
        with {:ok, human_value} <- extract_human_value(human_tlv),
             {:ok, binary_value} <- ValueParser.parse_value(:hex_string, human_value) do
          binary_tlv = %{
            type: type,
            length: byte_size(binary_value),
            value: binary_value
          }
          {:ok, binary_tlv}
        else
          {:error, reason} ->
            tlv_info = "TLV #{Map.get(human_tlv, "type", "unknown")}"
            {:error, "#{tlv_info}: #{reason}"}
        end
      else
        # Check if this TLV has subtlvs (compound TLV)
        case Map.get(human_tlv, "subtlvs") do
          subtlvs when is_list(subtlvs) and length(subtlvs) > 0 ->
            # Convert compound TLV with subtlvs
            convert_compound_tlv_to_binary(type, subtlvs, docsis_version)
            
          _ ->
            # Convert simple TLV
            with {:ok, human_value} <- extract_human_value(human_tlv),
                 {:ok, binary_value} <- ValueParser.parse_value(value_type, human_value) do
              binary_tlv = %{
                type: type,
                length: byte_size(binary_value),
                value: binary_value
              }

              {:ok, binary_tlv}
            else
              {:error, reason} ->
                tlv_info = "TLV #{Map.get(human_tlv, "type", "unknown")}"
                {:error, "#{tlv_info}: #{reason}"}
            end
        end
      end
    else
      {:error, reason} ->
        tlv_info = "TLV #{Map.get(human_tlv, "type", "unknown")}"
        {:error, "#{tlv_info}: #{reason}"}
    end
  end
  
  defp convert_compound_tlv_to_binary(type, subtlvs, docsis_version) do
    # Recursively convert all subtlvs to binary
    case convert_human_tlvs_to_binary(subtlvs, docsis_version) do
      {:ok, binary_subtlvs} ->
        # Concatenate all subtlv binaries
        subtlv_binary = Enum.reduce(binary_subtlvs, <<>>, fn subtlv, acc ->
          acc <> <<subtlv.type::8, subtlv.length::8>> <> subtlv.value
        end)
        
        binary_tlv = %{
          type: type,
          length: byte_size(subtlv_binary),
          value: subtlv_binary
        }
        
        {:ok, binary_tlv}
        
      {:error, reason} ->
        {:error, "Sub-TLV conversion failed: #{reason}"}
    end
  end

  defp extract_tlv_type(%{"type" => type}) when is_integer(type), do: {:ok, type}

  defp extract_tlv_type(%{"type" => type}) when is_binary(type) do
    case Integer.parse(type) do
      {parsed_type, ""} -> {:ok, parsed_type}
      _ -> {:error, "Invalid TLV type format"}
    end
  end

  defp extract_tlv_type(_), do: {:error, "Missing or invalid TLV type"}

  defp get_tlv_value_type(type, docsis_version, human_tlv) do
    # First check if the human TLV has an explicit value_type field
    case Map.get(human_tlv, "value_type") do
      nil ->
        # No explicit value_type, look up from DOCSIS specs
        case DocsisSpecs.get_tlv_info(type, docsis_version) do
          {:ok, tlv_info} -> {:ok, tlv_info.value_type}
          # Default to binary for unknown types
          {:error, _} -> {:ok, :binary}
        end

      explicit_value_type when is_binary(explicit_value_type) ->
        # Use the explicitly provided value_type
        {:ok, String.to_atom(explicit_value_type)}

      explicit_value_type when is_atom(explicit_value_type) ->
        # Already an atom
        {:ok, explicit_value_type}

      _ ->
        {:error, "Invalid value_type format"}
    end
  end

  # Public test function for testing extract_human_value behavior
  def extract_human_value_for_test(tlv_json) do
    extract_human_value(tlv_json)
  end

  # Extract human-editable data from TLV JSON structure
  # Compound TLVs with subtlvs take priority (even if they also have formatted_value)
  defp extract_human_value(%{"subtlvs" => subtlvs}) when is_list(subtlvs) do
    # For compound TLVs, convert subtlvs to a structured format for human editing
    case extract_subtlv_human_values(subtlvs) do
      {:ok, subtlv_values} -> {:ok, %{"subtlvs" => subtlv_values}}
      {:error, reason} -> {:error, reason}
    end
  end

  # Leaf TLVs have formatted_value for human editing
  defp extract_human_value(%{"formatted_value" => formatted_value}) do
    {:ok, formatted_value}
  end


  defp extract_human_value(%{"type" => type}) do
    {:error,
     "TLV #{type}: Missing both formatted_value and subtlvs - TLV structure may be invalid"}
  end

  defp extract_human_value(_) do
    {:error, "Invalid TLV structure - missing type, formatted_value, and subtlvs"}
  end

  # Recursively extract human values from subtlvs
  defp extract_subtlv_human_values(subtlvs) when is_list(subtlvs) do
    case Enum.reduce_while(subtlvs, {:ok, []}, fn subtlv, {:ok, acc} ->
           case extract_human_value(subtlv) do
             {:ok, human_value} ->
               subtlv_with_human_value = Map.merge(subtlv, %{"human_value" => human_value})
               {:cont, {:ok, [subtlv_with_human_value | acc]}}

             {:error, reason} ->
               {:halt, {:error, reason}}
           end
         end) do
      {:ok, subtlv_list} -> {:ok, Enum.reverse(subtlv_list)}
      {:error, reason} -> {:error, reason}
    end
  end

  defp generate_binary_config(binary_tlvs) do
    case Bindocsis.Generators.BinaryGenerator.generate(binary_tlvs) do
      {:ok, binary_config} -> {:ok, binary_config}
      {:error, reason} -> {:error, "Binary generation failed: #{reason}"}
    end
  end

  defp validate_binary_config(binary_config, docsis_version) do
    # Basic validation - ensure we can parse what we generated
    case Bindocsis.parse(binary_config, format: :binary, docsis_version: docsis_version) do
      {:ok, _parsed_tlvs} -> {:ok, :valid}
      {:error, reason} -> {:error, "Generated binary is invalid: #{reason}"}
    end
  end

  defp format_raw_value(value_type, raw_value) do
    case ValueFormatter.format_value(value_type, raw_value) do
      {:ok, formatted} -> formatted
      {:error, _} -> Base.encode16(raw_value)
    end
  end

  defp generate_yaml(human_config, opts) do
    include_descriptions = Keyword.get(opts, :include_descriptions, false)

    # Generate header comment
    header = """
    # Generated DOCSIS Configuration (Human-Readable Format)
    # Use this file to edit your DOCSIS configuration with human-friendly values
    # Frequencies: "591 MHz", "1.2 GHz"
    # Bandwidth: "100 Mbps", "1 Gbps"
    # IP Addresses: "192.168.1.100"
    # Booleans: "enabled", "disabled"
    # MAC Addresses: "00:11:22:33:44:55"

    """

    # Generate YAML manually since YamlElixir doesn't have write_to_string
    yaml_data = generate_yaml_manually(human_config, include_descriptions)

    header <> yaml_data
  end

  defp generate_yaml_manually(human_config, include_descriptions) do
    docsis_version = Map.get(human_config, "docsis_version", "3.1")
    tlvs = Map.get(human_config, "tlvs", [])
    metadata = Map.get(human_config, "metadata")

    yaml_lines = [
      "docsis_version: \"#{docsis_version}\"",
      "tlvs:"
    ]

    tlv_lines =
      Enum.flat_map(tlvs, fn tlv ->
        tlv_yaml = [
          "  - type: #{tlv["type"]}",
          "    name: \"#{tlv["name"]}\"",
          "    formatted_value: #{format_yaml_value(tlv["formatted_value"])}"
        ]

        tlv_yaml =
          if include_descriptions and tlv["description"] do
            ["    # #{tlv["description"]}" | tlv_yaml]
          else
            tlv_yaml
          end

        if tlv["raw_value"] do
          tlv_yaml ++ ["    raw_value: #{inspect(tlv["raw_value"])}"]
        else
          tlv_yaml
        end
      end)

    metadata_lines =
      if metadata do
        [
          "metadata:",
          "  total_tlvs: #{metadata["total_tlvs"] || 0}",
          "  parsed_at: \"#{metadata["parsed_at"] || ""}\""
        ]
      else
        []
      end

    all_lines = yaml_lines ++ tlv_lines ++ metadata_lines
    Enum.join(all_lines, "\n") <> "\n"
  end

  defp format_yaml_value(value) when is_binary(value), do: "\"#{value}\""
  defp format_yaml_value(value) when is_number(value), do: to_string(value)
  defp format_yaml_value(value) when is_boolean(value), do: to_string(value)
  defp format_yaml_value(value), do: inspect(value)

  defp make_json_serializable(value) when is_tuple(value) do
    # Convert tuples to lists for JSON compatibility
    Tuple.to_list(value)
  end

  defp make_json_serializable(value) when is_binary(value) do
    # Check if binary is printable, otherwise convert to hex
    if String.printable?(value) do
      value
    else
      Base.encode16(value)
    end
  end

  defp make_json_serializable(value), do: value

  defp create_template_config(:residential, _opts) do
    template_tlvs = [
      %{
        "type" => 1,
        "name" => "Downstream Frequency",
        "formatted_value" => "591 MHz",
        "description" => "Primary downstream channel frequency"
      },
      %{
        "type" => 2,
        "name" => "Upstream Channel ID",
        "formatted_value" => 2,
        "description" => "Upstream channel identifier"
      },
      %{
        "type" => 3,
        "name" => "Network Access Control",
        "formatted_value" => "enabled",
        "description" => "Enable network access for the modem"
      },
      %{
        "type" => 12,
        "name" => "Modem IP Address",
        "formatted_value" => "192.168.100.10",
        "description" => "IP address assigned to the cable modem"
      },
      %{
        "type" => 21,
        "name" => "Max CPE IP Addresses",
        "formatted_value" => 16,
        "description" => "Maximum number of customer devices"
      }
    ]

    {:ok, template_tlvs}
  end

  defp create_template_config(:business, _opts) do
    template_tlvs = [
      %{
        "type" => 1,
        "name" => "Downstream Frequency",
        "formatted_value" => "615 MHz",
        "description" => "Business-grade downstream frequency"
      },
      %{
        "type" => 2,
        "name" => "Upstream Channel ID",
        "formatted_value" => 1,
        "description" => "Primary upstream channel"
      },
      %{
        "type" => 3,
        "name" => "Network Access Control",
        "formatted_value" => "enabled",
        "description" => "Network access enabled"
      },
      %{
        "type" => 12,
        "name" => "Modem IP Address",
        "formatted_value" => "10.1.1.100",
        "description" => "Business network IP address"
      },
      %{
        "type" => 21,
        "name" => "Max CPE IP Addresses",
        "formatted_value" => 64,
        "description" => "Higher device limit for business use"
      }
    ]

    {:ok, template_tlvs}
  end

  defp create_template_config(:minimal, _opts) do
    template_tlvs = [
      %{
        "type" => 1,
        "name" => "Downstream Frequency",
        "formatted_value" => "591 MHz"
      },
      %{
        "type" => 3,
        "name" => "Network Access Control",
        "formatted_value" => "enabled"
      }
    ]

    {:ok, template_tlvs}
  end

  defp create_template_config(unknown_type, _opts) do
    {:error, "Unknown template type: #{unknown_type}"}
  end

  defp get_template_description(:residential),
    do: "Standard residential cable modem configuration"

  defp get_template_description(:business),
    do: "Business-grade configuration with enhanced features"

  defp get_template_description(:minimal), do: "Minimal working configuration for testing"
  defp get_template_description(:gigabit), do: "High-speed gigabit service configuration"
  defp get_template_description(:ipv6), do: "IPv6-enabled configuration"
  defp get_template_description(_), do: "Custom DOCSIS configuration template"

  @doc """
  Gets all available template types.
  """
  @spec get_available_templates() :: [atom()]
  def get_available_templates do
    [:residential, :business, :minimal, :gigabit, :ipv6]
  end
end
