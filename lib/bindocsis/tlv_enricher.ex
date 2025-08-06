defmodule Bindocsis.TlvEnricher do
  @moduledoc """
  TLV metadata enrichment module.

  Provides functionality to enhance parsed TLVs with rich metadata including
  names, descriptions, value types, and DOCSIS version information.

  ## Features

  - **Universal metadata application** - Enriches TLVs with comprehensive specs
  - **DOCSIS and MTA support** - Handles both standard DOCSIS and PacketCable MTA TLVs
  - **Backward compatibility** - Optional enrichment with fallback to basic TLV structure
  - **Performance optimized** - Minimal overhead with optional lazy loading

  ## Usage

      iex> basic_tlv = %{type: 3, length: 1, value: <<1>>}
      iex> Bindocsis.TlvEnricher.enrich_tlv(basic_tlv)
      %{
        type: 3,
        length: 1,
        value: <<1>>,
        name: "Network Access Control",
        description: "Enable/disable network access",
        value_type: :uint8,
        introduced_version: "1.0",
        docsis_category: :basic_configuration
      }
  """

  alias Bindocsis.DocsisSpecs
  alias Bindocsis.MtaSpecs
  alias Bindocsis.SubTlvSpecs
  alias Bindocsis.ValueFormatter

  @type basic_tlv :: %{
          type: non_neg_integer(),
          length: non_neg_integer(),
          value: binary()
        }

  @type enhanced_tlv :: %{
          type: non_neg_integer(),
          length: non_neg_integer(),
          value: binary(),
          name: String.t(),
          description: String.t(),
          value_type: atom(),
          introduced_version: String.t(),
          docsis_category: atom(),
          subtlv_support: boolean(),
          max_length: non_neg_integer() | :unlimited,
          formatted_value: String.t() | map() | nil,
          raw_value: any() | nil,
          metadata_source: atom()
        }

  @type enrichment_options :: [
          enhanced: boolean(),
          docsis_version: String.t(),
          include_mta: boolean(),
          lazy_load: boolean(),
          format_values: boolean(),
          format_style: :compact | :verbose,
          format_precision: non_neg_integer()
        ]

  # DOCSIS TLV Categories for better organization
  @docsis_categories %{
    # Basic Configuration (1-30)
    (1..30) => :basic_configuration,
    # Security & Privacy (31-42)
    (31..42) => :security_privacy,
    # Advanced Features (43-63)
    (43..63) => :advanced_features,
    # DOCSIS 3.0 Extensions (64-76)
    (64..76) => :docsis_3_0_extensions,
    # DOCSIS 3.1 Extensions (77-85)
    (77..85) => :docsis_3_1_extensions,
    # PacketCable MTA (64, 67, 122, etc.)
    [64, 67, 122] => :packet_cable_mta,
    # Vendor Specific (200-254)
    (200..254) => :vendor_specific
  }

  @doc """
  Enriches a single TLV with comprehensive metadata.

  ## Parameters

  - `tlv` - Basic TLV map with :type, :length, :value
  - `opts` - Enrichment options (optional)

  ## Options

  - `:enhanced` - Enable/disable metadata enrichment (default: true)
  - `:docsis_version` - Target DOCSIS version (default: "3.1")
  - `:include_mta` - Include PacketCable MTA TLV support (default: true)
  - `:lazy_load` - Defer expensive metadata loading (default: false)
  - `:format_values` - Enable smart value formatting (default: true)
  - `:format_style` - Format style :compact or :verbose (default: :compact)
  - `:format_precision` - Decimal precision for formatted values (default: 2)

  ## Examples

      iex> tlv = %{type: 1, length: 4, value: <<35, 57, 241, 192>>}
      iex> Bindocsis.TlvEnricher.enrich_tlv(tlv)
      %{
        type: 1,
        length: 4,
        value: <<35, 57, 241, 192>>,
        name: "Downstream Frequency",
        description: "Center frequency of the downstream channel in Hz",
        value_type: :frequency,
        docsis_category: :basic_configuration
      }

      iex> Bindocsis.TlvEnricher.enrich_tlv(tlv, enhanced: false)
      %{type: 1, length: 4, value: <<35, 57, 241, 192>>}  # Unchanged
  """
  @spec enrich_tlv(basic_tlv(), enrichment_options()) :: enhanced_tlv() | basic_tlv()
  def enrich_tlv(tlv, opts \\ []) do
    enhanced = Keyword.get(opts, :enhanced, true)

    if enhanced do
      apply_metadata(tlv, opts)
    else
      # Return unchanged for backward compatibility
      tlv
    end
  end

  @doc """
  Enriches a list of TLVs with metadata.

  ## Examples

      iex> tlvs = [%{type: 3, length: 1, value: <<1>>}, %{type: 1, length: 4, value: <<...>>}]
      iex> Bindocsis.TlvEnricher.enrich_tlvs(tlvs)
      [%{type: 3, name: "Network Access Control", ...}, %{type: 1, name: "Downstream Frequency", ...}]
  """
  @spec enrich_tlvs([basic_tlv()], enrichment_options()) :: [enhanced_tlv()] | [basic_tlv()]
  def enrich_tlvs(tlvs, opts \\ []) when is_list(tlvs) do
    Enum.map(tlvs, &enrich_tlv(&1, opts))
  end

  @doc """
  Converts enriched TLVs back to basic TLV structures for binary generation.

  This function performs the reverse operation of enrichment, extracting only
  the core TLV data (type, length, value) needed for binary generation while
  properly handling recursive compound TLV structures.

  ## Parameters

  - `enriched_tlvs` - List of enriched TLV maps
  - `opts` - Options for unenrichment

  ## Options

  - `:strict` - Enable strict parsing mode for formatted_value parsing (default: `false`)
  - `:validate_round_trip` - Validate that parsing formatted_value produces the same binary (default: `false`)

  ## Examples

      iex> enriched_tlv = %{type: 3, value: <<1>>, formatted_value: "1"}
      iex> Bindocsis.TlvEnricher.unenrich_tlvs([enriched_tlv])
      [%{type: 3, length: 1, value: <<1>>}]

      iex> compound_tlv = %{type: 22, subtlvs: [%{type: 1, formatted_value: "5"}]}
      iex> Bindocsis.TlvEnricher.unenrich_tlvs([compound_tlv])
      [%{type: 22, length: 3, value: <<1, 1, 5>>}]
  """
  @spec unenrich_tlvs([enhanced_tlv()], keyword()) :: [basic_tlv()]
  def unenrich_tlvs(enriched_tlvs, opts \\ []) when is_list(enriched_tlvs) do
    Enum.map(enriched_tlvs, &unenrich_tlv(&1, opts))
  end

  @doc """
  Converts a single enriched TLV back to basic TLV structure.

  For compound TLVs with subtlvs, recursively processes the subtlvs and
  regenerates the binary value. For leaf TLVs with formatted_value,
  parses the formatted value back to binary using the value_type.
  """
  @spec unenrich_tlv(enhanced_tlv(), keyword()) :: basic_tlv()
  def unenrich_tlv(enriched_tlv, opts \\ [])

  # Compound TLV - has subtlvs array
  def unenrich_tlv(%{type: type, subtlvs: subtlvs} = _tlv, opts)
      when is_list(subtlvs) and length(subtlvs) > 0 do
    # Recursively unenrich all subtlvs
    raw_subtlvs = unenrich_tlvs(subtlvs, opts)

    # Serialize subtlvs back to binary
    binary_value = serialize_subtlvs_to_binary(raw_subtlvs)

    %{
      type: type,
      length: byte_size(binary_value),
      value: binary_value
    }
  end

  # Leaf TLV - has formatted_value or existing value
  def unenrich_tlv(
        %{
          type: type,
          value: existing_value,
          formatted_value: formatted_value,
          value_type: value_type
        } = _tlv,
        opts
      )
      when is_binary(formatted_value) and not is_nil(value_type) do
    # Parse formatted_value back to binary using value_type
    case parse_formatted_value_to_binary(formatted_value, value_type, opts) do
      {:ok, parsed_value} ->
        %{
          type: type,
          length: byte_size(parsed_value),
          value: parsed_value
        }

      {:error, _reason} ->
        # Fallback to existing value if parsing fails
        %{
          type: type,
          length: byte_size(existing_value),
          value: existing_value
        }
    end
  end

  # TLV with existing binary value but no formatted_value
  def unenrich_tlv(%{type: type, value: value} = _tlv, _opts) when is_binary(value) do
    %{
      type: type,
      length: byte_size(value),
      value: value
    }
  end

  # TLV with length field already present (backward compatibility)
  def unenrich_tlv(%{type: type, length: length, value: value} = _tlv, _opts) do
    %{
      type: type,
      length: length,
      value: value
    }
  end

  # Private Functions

  @spec apply_metadata(basic_tlv(), enrichment_options()) :: enhanced_tlv()
  defp apply_metadata(%{type: type, value: value} = tlv, opts) do
    docsis_version = Keyword.get(opts, :docsis_version, "3.1")
    include_mta = Keyword.get(opts, :include_mta, true)
    format_values = Keyword.get(opts, :format_values, true)

    # Try to get metadata from DOCSIS specs first, then MTA specs
    metadata = get_tlv_metadata(type, docsis_version, include_mta)

    # Add value formatting if enabled
    enhanced_metadata =
      if format_values do
        add_formatted_value(metadata, value, opts)
      else
        Map.merge(metadata, %{formatted_value: nil, raw_value: nil})
      end

    # Add comprehensive sub-TLV parsing for all compound TLVs
    final_metadata =
      if Map.get(metadata, :subtlv_support, false) do
        add_compound_tlv_subtlvs(enhanced_metadata, type, value, opts)
      else
        enhanced_metadata
      end

    # Merge basic TLV with enriched metadata
    Map.merge(tlv, final_metadata)
  end

  # Enriches a single subtlv using subtlv specs from the parent TLV context.
  # This is the recursive enrichment function for nested TLV structures.
  @spec enrich_subtlv(map(), map(), enrichment_options()) :: map()
  defp enrich_subtlv(%{type: subtlv_type, value: subtlv_value} = subtlv, subtlv_specs, opts) do
    format_values = Keyword.get(opts, :format_values, true)

    # Get metadata for this subtlv type from the parent's subtlv specs
    metadata =
      case Map.get(subtlv_specs, subtlv_type) do
        nil ->
          # Unknown subtlv type
          %{
            name: "Unknown SubTLV #{subtlv_type}",
            description: "SubTLV type #{subtlv_type} - no specification available",
            value_type: :unknown
          }

        spec ->
          spec
      end

    # Add value formatting if enabled - SAME as top-level TLVs
    enhanced_metadata =
      if format_values do
        add_formatted_value(metadata, subtlv_value, opts)
      else
        Map.merge(metadata, %{formatted_value: nil, raw_value: nil})
      end

    # Check if this subtlv itself has nested subtlvs (recursive compound structures)
    final_metadata =
      if Map.get(metadata, :value_type) == :compound do
        add_compound_tlv_subtlvs(enhanced_metadata, subtlv_type, subtlv_value, opts)
      else
        enhanced_metadata
      end

    # Merge basic subtlv with enriched metadata - SAME as top-level TLVs
    Map.merge(subtlv, final_metadata)
  end

  @spec get_tlv_metadata(non_neg_integer(), String.t(), boolean()) :: map()
  defp get_tlv_metadata(type, docsis_version, include_mta) do
    # Try DOCSIS specs first
    case DocsisSpecs.get_tlv_info(type, docsis_version) do
      {:ok, docsis_info} ->
        enhance_with_docsis_metadata(docsis_info, type)

      {:error, _} when include_mta ->
        # Fallback to MTA specs for PacketCable TLVs
        case MtaSpecs.get_tlv_info(type, "2.0") do
          {:ok, mta_info} ->
            enhance_with_mta_metadata(mta_info, type)

          {:error, _} ->
            create_unknown_tlv_metadata(type)
        end

      {:error, _} ->
        create_unknown_tlv_metadata(type)
    end
  end

  @spec enhance_with_docsis_metadata(map(), non_neg_integer()) :: map()
  defp enhance_with_docsis_metadata(docsis_info, type) do
    %{
      name: docsis_info.name,
      description: docsis_info.description,
      value_type: docsis_info.value_type,
      introduced_version: docsis_info.introduced_version,
      subtlv_support: docsis_info.subtlv_support,
      max_length: docsis_info.max_length,
      docsis_category: get_docsis_category(type),
      metadata_source: :docsis_specs
    }
  end

  @spec enhance_with_mta_metadata(map(), non_neg_integer()) :: map()
  defp enhance_with_mta_metadata(mta_info, _type) do
    %{
      name: mta_info.name,
      description: mta_info.description,
      value_type: mta_info.value_type,
      introduced_version: mta_info.introduced_version,
      subtlv_support: mta_info.subtlv_support,
      max_length: mta_info.max_length,
      docsis_category: :packet_cable_mta,
      mta_specific: Map.get(mta_info, :mta_specific, true),
      metadata_source: :mta_specs
    }
  end

  @spec create_unknown_tlv_metadata(non_neg_integer()) :: map()
  defp create_unknown_tlv_metadata(type) do
    %{
      name: "Unknown TLV #{type}",
      description: "TLV type #{type} - no specification available",
      value_type: :unknown,
      introduced_version: "Unknown",
      subtlv_support: false,
      max_length: :unlimited,
      docsis_category: get_docsis_category(type),
      metadata_source: :unknown
    }
  end

  @spec add_formatted_value(map(), binary(), enrichment_options()) :: map()
  defp add_formatted_value(%{value_type: value_type} = metadata, binary_value, opts) do
    format_opts = [
      format_style: Keyword.get(opts, :format_style, :compact),
      precision: Keyword.get(opts, :format_precision, 2)
    ]

    case ValueFormatter.format_value(value_type, binary_value, format_opts) do
      {:ok, formatted_value} ->
        raw_value = extract_raw_value(value_type, binary_value)

        Map.merge(metadata, %{
          formatted_value: formatted_value,
          raw_value: raw_value
        })

      {:error, _reason} ->
        # Fallback to binary formatting if specific formatting fails
        case ValueFormatter.format_value(:binary, binary_value, format_opts) do
          {:ok, hex_value} ->
            Map.merge(metadata, %{
              formatted_value: hex_value,
              raw_value: binary_value
            })

          {:error, _} ->
            Map.merge(metadata, %{
              formatted_value: nil,
              raw_value: binary_value
            })
        end
    end
  end

  @spec extract_raw_value(atom(), binary()) :: any()
  defp extract_raw_value(:uint8, <<value::8>>), do: value
  defp extract_raw_value(:uint16, <<value::16>>), do: value
  defp extract_raw_value(:uint32, <<value::32>>), do: value
  defp extract_raw_value(:enum, <<value::8>>), do: value
  defp extract_raw_value(:power_quarter_db, <<value::8>>), do: value / 4.0
  defp extract_raw_value(:frequency, <<value::32>>), do: value
  defp extract_raw_value(:bandwidth, <<value::32>>), do: value
  defp extract_raw_value(:boolean, <<0>>), do: false
  defp extract_raw_value(:boolean, <<1>>), do: true
  defp extract_raw_value(:percentage, <<value::8>>), do: value
  defp extract_raw_value(:duration, <<value::32>>), do: value
  defp extract_raw_value(:service_flow_ref, <<0, ref::8>>), do: ref
  defp extract_raw_value(:service_flow_ref, <<ref::16>>), do: ref
  defp extract_raw_value(:ipv4, <<a, b, c, d>>), do: {a, b, c, d}
  defp extract_raw_value(:mac_address, <<a, b, c, d, e, f>>), do: {a, b, c, d, e, f}

  defp extract_raw_value(:string, binary_value) when is_binary(binary_value) do
    String.trim_trailing(binary_value, <<0>>)
  end

  defp extract_raw_value(_type, binary_value), do: binary_value

  @spec get_docsis_category(non_neg_integer()) :: atom()
  defp get_docsis_category(type) do
    @docsis_categories
    |> Enum.find(fn
      {range, _category} when is_struct(range, Range) -> type in range
      {list, _category} when is_list(list) -> type in list
      _ -> false
    end)
    |> case do
      {_range, category} -> category
      nil -> :uncategorized
    end
  end

  @doc """
  Checks if a TLV has been enriched with metadata.

  ## Examples

      iex> basic_tlv = %{type: 3, length: 1, value: <<1>>}
      iex> Bindocsis.TlvEnricher.enriched?(basic_tlv)
      false

      iex> enhanced_tlv = Bindocsis.TlvEnricher.enrich_tlv(basic_tlv)
      iex> Bindocsis.TlvEnricher.enriched?(enhanced_tlv)
      true
  """
  @spec enriched?(map()) :: boolean()
  def enriched?(%{name: _name, description: _description}), do: true
  def enriched?(_tlv), do: false

  @doc """
  Strips metadata from an enriched TLV, returning basic structure.

  Useful for backward compatibility or when you need just the core TLV data.

  ## Examples

      iex> enhanced_tlv = %{type: 3, length: 1, value: <<1>>, name: "Network Access Control", description: "..."}
      iex> Bindocsis.TlvEnricher.strip_metadata(enhanced_tlv)
      %{type: 3, length: 1, value: <<1>>}
  """
  @spec strip_metadata(enhanced_tlv()) :: basic_tlv()
  def strip_metadata(tlv) do
    Map.take(tlv, [:type, :length, :value])
  end

  @doc """
  Gets enrichment statistics for a list of TLVs.

  ## Examples

      iex> tlvs = [enhanced_tlv1, basic_tlv2, enhanced_tlv3]
      iex> Bindocsis.TlvEnricher.enrichment_stats(tlvs)
      %{
        total_tlvs: 3,
        enriched_tlvs: 2,
        enrichment_percentage: 66.7,
        categories: %{basic_configuration: 2, advanced_features: 1},
        metadata_sources: %{docsis_specs: 2, mta_specs: 0, unknown: 0}
      }
  """
  @spec enrichment_stats([map()]) :: map()
  def enrichment_stats(tlvs) when is_list(tlvs) do
    total = length(tlvs)
    enriched = Enum.count(tlvs, &enriched?/1)

    categories =
      tlvs
      |> Enum.filter(&enriched?/1)
      |> Enum.group_by(& &1.docsis_category)
      |> Map.new(fn {category, tlv_list} -> {category, length(tlv_list)} end)

    sources =
      tlvs
      |> Enum.filter(&enriched?/1)
      |> Enum.group_by(&Map.get(&1, :metadata_source, :unknown))
      |> Map.new(fn {source, tlv_list} -> {source, length(tlv_list)} end)

    %{
      total_tlvs: total,
      enriched_tlvs: enriched,
      enrichment_percentage: if(total > 0, do: Float.round(enriched / total * 100, 1), else: 0.0),
      categories: categories,
      metadata_sources: sources
    }
  end

  # Compound TLV SubTLV Parsing Functions

  @spec add_compound_tlv_subtlvs(map(), non_neg_integer(), binary(), enrichment_options()) ::
          map()
  defp add_compound_tlv_subtlvs(metadata, type, value, opts) do
    case parse_compound_tlv_subtlvs(type, value, opts) do
      {:ok, subtlvs} ->
        # For compound TLVs, the subtlvs array IS the human-editable structure
        # Remove the string formatted_value and just use subtlvs
        metadata
        |> Map.put(:subtlvs, subtlvs)
        |> Map.delete(:formatted_value)

      {:error, reason} ->
        require Logger
        Logger.warning("Failed to parse compound TLV subtlvs for TLV #{type}: #{reason}")
        Map.put(metadata, :subtlvs, [])
    end
  end

  @spec parse_compound_tlv_subtlvs(non_neg_integer(), binary(), enrichment_options()) ::
          {:ok, [map()]} | {:error, String.t()}
  defp parse_compound_tlv_subtlvs(type, binary_value, opts) do
    case SubTlvSpecs.get_subtlv_specs(type) do
      {:ok, subtlv_specs} ->
        case parse_tlv_binary(binary_value) do
          {:ok, raw_subtlvs} ->
            # RECURSIVE: Process each subtlv with subtlv-aware enrichment
            enriched_subtlvs =
              Enum.map(raw_subtlvs, fn subtlv ->
                enrich_subtlv(subtlv, subtlv_specs, opts)
              end)

            {:ok, enriched_subtlvs}

          {:error, reason} ->
            {:error, reason}
        end

      {:error, :unknown_tlv} ->
        # Fallback to legacy service flow parsing for backward compatibility
        legacy_parse_service_flow_subtlvs(type, binary_value, opts)

      {:error, reason} ->
        {:error, reason}
    end
  end

  # Legacy fallback for service flow TLVs not yet in SubTlvSpecs
  defp legacy_parse_service_flow_subtlvs(type, binary_value, opts) when type in [24, 25] do
    case DocsisSpecs.get_service_flow_subtlvs(type) do
      {:ok, subtlv_specs} ->
        case parse_tlv_binary(binary_value) do
          {:ok, raw_subtlvs} ->
            enriched_subtlvs =
              Enum.map(raw_subtlvs, fn subtlv ->
                enrich_service_flow_subtlv(subtlv, subtlv_specs, opts)
              end)

            {:ok, enriched_subtlvs}

          {:error, reason} ->
            {:error, reason}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp legacy_parse_service_flow_subtlvs(26, binary_value, opts) do
    # TLV 26 (PHS Rule) uses different subtlv structure
    case parse_tlv_binary(binary_value) do
      {:ok, raw_subtlvs} ->
        enriched_subtlvs =
          Enum.map(raw_subtlvs, fn subtlv ->
            enrich_phs_subtlv(subtlv, opts)
          end)

        {:ok, enriched_subtlvs}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp legacy_parse_service_flow_subtlvs(type, _binary_value, _opts) do
    {:error, "Unsupported compound TLV type: #{type}"}
  end

  @spec enrich_compound_subtlv(map(), map(), enrichment_options()) :: map()
  defp enrich_compound_subtlv(
         %{type: subtlv_type, value: subtlv_value} = subtlv,
         subtlv_specs,
         opts
       ) do
    case Map.get(subtlv_specs, subtlv_type) do
      nil ->
        # Unknown subtlv type
        Map.merge(subtlv, %{
          name: "Unknown SubTLV #{subtlv_type}",
          description: "SubTLV type #{subtlv_type} - no specification available",
          value_type: :unknown,
          formatted_value: format_binary_value(subtlv_value)
        })

      subtlv_spec ->
        # Known subtlv with comprehensive specification
        formatted_value =
          format_compound_subtlv_value(subtlv_spec, subtlv_value, opts)

        enriched_subtlv = %{
          name: subtlv_spec.name,
          description: subtlv_spec.description,
          value_type: subtlv_spec.value_type,
          max_length: subtlv_spec.max_length,
          formatted_value: formatted_value
        }

        # Add enum values if present
        enriched_subtlv =
          if Map.has_key?(subtlv_spec, :enum_values) do
            Map.put(enriched_subtlv, :enum_values, subtlv_spec.enum_values)
          else
            enriched_subtlv
          end

        # Add raw value extraction
        enriched_subtlv =
          if subtlv_spec.value_type in [:enum, :uint8, :uint16, :uint32] do
            raw_value = extract_raw_value(subtlv_spec.value_type, subtlv_value)
            Map.put(enriched_subtlv, :raw_value, raw_value)
          else
            enriched_subtlv
          end

        Map.merge(subtlv, enriched_subtlv)
    end
  end

  @spec format_compound_subtlv_value(map(), binary(), enrichment_options()) :: String.t()
  defp format_compound_subtlv_value(subtlv_spec, binary_value, opts) do
    format_opts = [
      format_style: Keyword.get(opts, :format_style, :compact),
      precision: Keyword.get(opts, :format_precision, 2)
    ]

    # Check if this sub-TLV has enum values defined
    enum_values = Map.get(subtlv_spec, :enum_values, nil)

    if enum_values != nil and is_map(enum_values) do
      # This sub-TLV has enum values - format with enum lookup
      format_enum_value(subtlv_spec.value_type, binary_value, enum_values, opts)
    else
      # No enum values - use standard formatting
      case ValueFormatter.format_value(subtlv_spec.value_type, binary_value, format_opts) do
        {:ok, formatted} -> formatted
        {:error, _} -> format_binary_value(binary_value)
      end
    end
  end

  @spec format_enum_value(atom(), binary(), map(), enrichment_options()) :: String.t()
  defp format_enum_value(value_type, binary_value, enum_values, opts) do
    format_style = Keyword.get(opts, :format_style, :compact)

    # Extract the raw integer value based on the underlying type
    raw_value =
      case value_type do
        :uint8 -> extract_raw_value(:uint8, binary_value)
        :uint16 -> extract_raw_value(:uint16, binary_value)
        :uint32 -> extract_raw_value(:uint32, binary_value)
        # Default enum to uint8
        :enum -> extract_raw_value(:uint8, binary_value)
        _ -> nil
      end

    case raw_value do
      val when is_integer(val) ->
        case Map.get(enum_values, val) do
          nil ->
            case format_style do
              :verbose -> "#{val} (Unknown enum value)"
              _ -> "#{val} (unknown)"
            end

          enum_name ->
            case format_style do
              :verbose -> "#{val} (#{enum_name})"
              _ -> enum_name
            end
        end

      _ ->
        format_binary_value(binary_value)
    end
  end

  @spec enrich_service_flow_subtlv(map(), map(), enrichment_options()) :: map()
  defp enrich_service_flow_subtlv(
         %{type: subtlv_type, value: subtlv_value} = subtlv,
         subtlv_specs,
         opts
       ) do
    case Map.get(subtlv_specs, subtlv_type) do
      nil ->
        # Unknown subtlv type
        Map.merge(subtlv, %{
          name: "Unknown SubTLV #{subtlv_type}",
          description: "Service flow subtlv type #{subtlv_type} - no specification available",
          value_type: :unknown,
          formatted_value: format_binary_value(subtlv_value)
        })

      subtlv_spec ->
        # Known subtlv with specification
        formatted_value =
          format_service_flow_subtlv_value(subtlv_spec.value_type, subtlv_value, opts)

        Map.merge(subtlv, %{
          name: subtlv_spec.name,
          description: subtlv_spec.description,
          value_type: subtlv_spec.value_type,
          max_length: subtlv_spec.max_length,
          formatted_value: formatted_value
        })
    end
  end

  @spec enrich_phs_subtlv(map(), enrichment_options()) :: map()
  defp enrich_phs_subtlv(%{type: subtlv_type, value: subtlv_value} = subtlv, _opts) do
    {name, description} =
      case subtlv_type do
        1 ->
          {"PHS Classifier Reference", "Reference to the classifier for this PHS rule"}

        2 ->
          {"PHS Rule", "Payload header suppression rule definition"}

        3 ->
          {"PHS Index", "Index of the PHS rule"}

        4 ->
          {"PHS Mask", "Mask applied to the payload header"}

        5 ->
          {"PHS Size", "Size of the suppressed header in bytes"}

        6 ->
          {"PHS Verify", "Verification flag for PHS rule"}

        _ ->
          {"Unknown PHS SubTLV #{subtlv_type}",
           "PHS subtlv type #{subtlv_type} - no specification available"}
      end

    Map.merge(subtlv, %{
      name: name,
      description: description,
      value_type: :binary,
      formatted_value: format_binary_value(subtlv_value)
    })
  end

  @spec format_service_flow_subtlv_value(atom(), binary(), enrichment_options()) :: String.t()
  defp format_service_flow_subtlv_value(value_type, binary_value, opts) do
    format_opts = [
      format_style: Keyword.get(opts, :format_style, :compact),
      precision: Keyword.get(opts, :format_precision, 2)
    ]

    case ValueFormatter.format_value(value_type, binary_value, format_opts) do
      {:ok, formatted} -> formatted
      {:error, _} -> format_binary_value(binary_value)
    end
  end

  @spec format_binary_value(binary()) :: String.t()
  defp format_binary_value(binary_value) do
    binary_value
    |> :binary.bin_to_list()
    |> Enum.map(&Integer.to_string(&1, 16))
    |> Enum.map(&String.pad_leading(&1, 2, "0"))
    |> Enum.join(" ")
    |> String.upcase()
  end

  @spec parse_tlv_binary(binary()) :: {:ok, [map()]} | {:error, String.t()}
  defp parse_tlv_binary(binary) do
    try do
      subtlvs = parse_subtlv_data(binary, [])
      {:ok, subtlvs}
    rescue
      e -> {:error, "TLV parsing error: #{Exception.message(e)}"}
    end
  end

  @spec parse_subtlv_data(binary(), [map()]) :: [map()]
  defp parse_subtlv_data(<<>>, acc), do: Enum.reverse(acc)

  defp parse_subtlv_data(<<type::8, length::8, rest::binary>>, acc)
       when byte_size(rest) >= length do
    <<value::binary-size(length), remaining::binary>> = rest
    subtlv = %{type: type, length: length, value: value}
    parse_subtlv_data(remaining, [subtlv | acc])
  end

  # Helper functions for unenrichment

  @spec serialize_subtlvs_to_binary([basic_tlv()]) :: binary()
  defp serialize_subtlvs_to_binary(subtlvs) do
    subtlvs
    |> Enum.map(&serialize_single_tlv/1)
    |> IO.iodata_to_binary()
  end

  @spec serialize_single_tlv(basic_tlv()) :: iodata()
  defp serialize_single_tlv(%{type: type, length: length, value: value}) do
    # Encode just like BinaryGenerator but without validation
    length_bytes = encode_tlv_length(length)
    [<<type>>, length_bytes, value]
  end

  @spec encode_tlv_length(non_neg_integer()) :: binary()
  defp encode_tlv_length(length) when length >= 0 and length <= 127 do
    <<length>>
  end

  defp encode_tlv_length(length) when length >= 128 and length <= 255 do
    <<0x81, length>>
  end

  defp encode_tlv_length(length) when length >= 256 and length <= 65535 do
    <<0x82, length::16>>
  end

  defp encode_tlv_length(length) when length >= 65536 and length <= 4_294_967_295 do
    <<0x84, length::32>>
  end

  @spec parse_formatted_value_to_binary(String.t(), atom(), keyword()) ::
          {:ok, binary()} | {:error, String.t()}
  defp parse_formatted_value_to_binary(formatted_value, value_type, opts) do
    # Use the ValueParser to convert formatted_value back to binary
    strict = Keyword.get(opts, :strict, false)
    validate_round_trip = Keyword.get(opts, :validate_round_trip, false)

    parse_opts = [strict: strict]

    case Bindocsis.ValueParser.parse_value(value_type, formatted_value, parse_opts) do
      {:ok, binary_value} ->
        if validate_round_trip do
          # Validate that formatting the binary produces the same formatted_value
          case ValueFormatter.format_value(value_type, binary_value, []) do
            {:ok, round_trip_formatted} ->
              if formatted_value == round_trip_formatted do
                {:ok, binary_value}
              else
                {:error,
                 "Round-trip validation failed: #{formatted_value} != #{round_trip_formatted}"}
              end

            {:error, reason} ->
              {:error, "Round-trip validation failed: #{reason}"}
          end
        else
          {:ok, binary_value}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end
end
