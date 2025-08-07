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

    # Attempt compound parsing only if:
    # 1. TLV is known to support subtlvs in specs, OR
    # 2. Binary value is long enough to contain subtlvs (at least 3 bytes)
    final_metadata =
      if should_attempt_compound_parsing?(metadata, value) do
        case add_compound_tlv_subtlvs(enhanced_metadata, type, value, opts) do
          %{subtlvs: subtlvs} = enriched when is_list(subtlvs) and length(subtlvs) > 0 ->
            # SUCCESS: Found actual subtlvs - override value_type to compound
            Map.put(enriched, :value_type, :compound)

          compound_metadata ->
            # Either failed or succeeded with no subtlvs - use the returned metadata
            # (which may have been converted to binary type with formatted_value)
            compound_metadata
        end
      else
        # Don't attempt compound parsing - keep original metadata
        enhanced_metadata
      end

    # Merge basic TLV with enriched metadata
    Map.merge(tlv, final_metadata)
  end

  # Enriches a single subtlv using RECURSIVE enrichment - treat subtlvs exactly like top-level TLVs
  @spec enrich_subtlv(map(), map(), enrichment_options()) :: map()
  defp enrich_subtlv(%{type: subtlv_type, value: subtlv_value} = subtlv, _subtlv_specs, opts) do
    # RECURSIVE: Treat this subtlv exactly like a top-level TLV
    # Don't use parent's subtlv_specs - get the authoritative metadata for this TLV type
    docsis_version = Keyword.get(opts, :docsis_version, "3.1")
    include_mta = Keyword.get(opts, :include_mta, true)
    format_values = Keyword.get(opts, :format_values, true)

    # Get authoritative metadata for this TLV type (same as top-level TLVs)
    metadata = get_tlv_metadata(subtlv_type, docsis_version, include_mta)

    # Add value formatting if enabled - SAME as top-level TLVs
    enhanced_metadata =
      if format_values do
        add_formatted_value(metadata, subtlv_value, opts)
      else
        Map.merge(metadata, %{formatted_value: nil, raw_value: nil})
      end

    # Apply same compound parsing logic as top-level TLVs - respect size constraints
    final_metadata =
      if should_attempt_compound_parsing?(enhanced_metadata, subtlv_value) do
        case add_compound_tlv_subtlvs(enhanced_metadata, subtlv_type, subtlv_value, opts) do
          %{subtlvs: subtlvs} = enriched when is_list(subtlvs) and length(subtlvs) > 0 ->
            # SUCCESS: Found actual subtlvs - override value_type to compound
            Map.put(enriched, :value_type, :compound)

          compound_metadata ->
            # Either failed or succeeded with no subtlvs - use the returned metadata
            # (which may have been converted to hex_string with formatted_value)
            compound_metadata
        end
      else
        # Don't attempt compound parsing - keep original metadata (single-byte subtlvs)
        enhanced_metadata
      end

    # Merge basic subtlv with enriched metadata - SAME as top-level TLVs
    Map.merge(subtlv, final_metadata)
  end

  # Enriches a subtlv using context-aware subtlv specs (for known compound TLV parents)
  @spec enrich_subtlv_with_specs(map(), map(), enrichment_options()) :: map()
  defp enrich_subtlv_with_specs(
         %{type: subtlv_type, value: subtlv_value} = subtlv,
         subtlv_specs,
         opts
       ) do
    format_values = Keyword.get(opts, :format_values, true)

    # Get metadata for this subtlv type from the parent's subtlv specs
    metadata =
      case Map.get(subtlv_specs, subtlv_type) do
        nil ->
          # Unknown subtlv type - fall back to recursive approach
          docsis_version = Keyword.get(opts, :docsis_version, "3.1")
          include_mta = Keyword.get(opts, :include_mta, true)
          get_tlv_metadata(subtlv_type, docsis_version, include_mta)

        spec ->
          spec
      end

    # Add value formatting if enabled
    enhanced_metadata =
      if format_values do
        add_formatted_value(metadata, subtlv_value, opts)
      else
        Map.merge(metadata, %{formatted_value: nil, raw_value: nil})
      end

    # Check if this subtlv itself has nested subtlvs (recursive compound structures)
    final_metadata =
      case add_compound_tlv_subtlvs(enhanced_metadata, subtlv_type, subtlv_value, opts) do
        %{subtlvs: subtlvs} = enriched when is_list(subtlvs) and length(subtlvs) > 0 ->
          # SUCCESS: Found actual subtlvs - override value_type to compound
          Map.put(enriched, :value_type, :compound)

        _no_subtlvs ->
          # No subtlvs found - keep original metadata
          enhanced_metadata
      end

    # Merge basic subtlv with enriched metadata
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

  # Infer appropriate value_type based on binary value size and content
  defp infer_value_type_from_binary(binary_value, length) when is_binary(binary_value) do
    case length do
      0 ->
        # Empty value - treat as marker/padding, not boolean!
        :marker
      1 -> 
        # Single byte could be uint8, boolean, or enum
        :uint8
      2 -> 
        # Two bytes likely uint16, could be frequency for some TLVs
        :uint16  
      3 ->
        # Three bytes unusual, default to binary
        :binary
      4 -> 
        # Four bytes likely uint32, could be frequency or IP address
        value = :binary.decode_unsigned(binary_value, :big)
        cond do
          # Large values that look like frequencies (> 1 MHz)
          value > 1_000_000 -> :frequency
          # Otherwise uint32
          true -> :uint32
        end
      6 ->
        # Six bytes likely MAC address
        :mac_address
      n when n >= 8 ->
        # Longer values likely strings or complex data
        :binary
      _ ->
        :binary
    end
  end

  defp infer_value_type_from_binary(_, _), do: :binary

  @spec add_formatted_value(map(), binary(), enrichment_options()) :: map()
  # Special case: Empty values should be markers, not their declared type
  defp add_formatted_value(metadata, <<>> = binary_value, _opts) do
    Map.merge(metadata, %{
      value_type: :marker,  # Override any type for empty values
      formatted_value: "",
      raw_value: binary_value
    })
  end
  
  defp add_formatted_value(%{value_type: :compound} = metadata, binary_value, _opts) do
    # Check if this is actually too small to be a compound TLV
    if byte_size(binary_value) < 3 do
      # Too small for compound - treat as binary/hex_string instead
      # Convert to hex string format per CLAUDE.md
      hex_value = binary_value
                 |> :binary.bin_to_list()
                 |> Enum.map(&Integer.to_string(&1, 16))
                 |> Enum.map(&String.pad_leading(&1, 2, "0"))
                 |> Enum.join(" ")
      
      Map.merge(metadata, %{
        value_type: :hex_string,  # Override compound type
        formatted_value: hex_value,
        raw_value: binary_value
      })
    else
      # Large enough to potentially be compound
      # Provide a fallback hex string in case add_compound_tlv_subtlvs doesn't set formatted_value
      hex_value = binary_value
                 |> :binary.bin_to_list()
                 |> Enum.map(&Integer.to_string(&1, 16))
                 |> Enum.map(&String.pad_leading(&1, 2, "0"))
                 |> Enum.join(" ")
      
      Map.merge(metadata, %{
        formatted_value: hex_value,  # Fallback hex string - will be overwritten by add_compound_tlv_subtlvs if successful
        raw_value: binary_value
      })
    end
  end

  defp add_formatted_value(%{value_type: :unknown} = metadata, binary_value, opts) do
    # Infer the appropriate value type from the binary data
    length = byte_size(binary_value)
    inferred_type = infer_value_type_from_binary(binary_value, length)
    
    # Update metadata with inferred type and format accordingly
    updated_metadata = Map.put(metadata, :value_type, inferred_type)
    add_formatted_value(updated_metadata, binary_value, opts)
  end

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
      {:ok, [_ | _] = subtlvs} ->
        # SUCCESS with actual subtlvs found
        compound_description = "Compound TLV with #{length(subtlvs)} sub-TLVs"

        metadata
        |> Map.put(:subtlvs, subtlvs)
        |> Map.put(:formatted_value, compound_description)

      {:ok, []} ->
        # SUCCESS but no subtlvs found - treat as failed compound TLV per CLAUDE.md guidance
        require Logger

        Logger.warning(
          "Compound TLV #{type} parsing succeeded but found no subtlvs - treating as binary with hex string fallback"
        )

        # Provide hex string as formatted_value for human editing since no subtlvs found
        hex_value = value
                   |> :binary.bin_to_list()
                   |> Enum.map(&Integer.to_string(&1, 16))
                   |> Enum.map(&String.pad_leading(&1, 2, "0"))
                   |> Enum.join(" ")
        
        # Update value_type to hex_string to ensure proper round-trip parsing
        metadata
        |> Map.put(:formatted_value, hex_value)
        |> Map.put(:value_type, :hex_string)

      {:error, reason} ->
        require Logger
        Logger.warning("Failed to parse compound TLV subtlvs for TLV #{type}: #{reason}")

        # Provide hex string as formatted_value for human editing since subtlv parsing failed
        hex_value = value
                   |> :binary.bin_to_list()
                   |> Enum.map(&Integer.to_string(&1, 16))
                   |> Enum.map(&String.pad_leading(&1, 2, "0"))
                   |> Enum.join(" ")
        
        # Update value_type to hex_string to ensure proper round-trip parsing
        metadata
        |> Map.put(:formatted_value, hex_value)
        |> Map.put(:value_type, :hex_string)
    end
  end

  @spec parse_compound_tlv_subtlvs(non_neg_integer(), binary(), enrichment_options()) ::
          {:ok, [map()]} | {:error, String.t()}
  defp parse_compound_tlv_subtlvs(parent_type, binary_value, opts) do
    case parse_tlv_binary(binary_value) do
      {:ok, raw_subtlvs} ->
        # Try to get context-aware subtlv specs for this parent type
        case SubTlvSpecs.get_subtlv_specs(parent_type) do
          {:ok, subtlv_specs} ->
            # Use context-aware specs for known compound TLVs
            enriched_subtlvs =
              Enum.map(raw_subtlvs, fn subtlv ->
                enrich_subtlv_with_specs(subtlv, subtlv_specs, opts)
              end)

            {:ok, enriched_subtlvs}

          {:error, :unknown_tlv} ->
            # Fall back to recursive approach for unknown compound TLVs
            enriched_subtlvs =
              Enum.map(raw_subtlvs, fn subtlv ->
                enrich_subtlv(subtlv, %{}, opts)
              end)

            {:ok, enriched_subtlvs}

          {:error, reason} ->
            {:error, reason}
        end

      {:error, reason} ->
        {:error, reason}
    end
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

  # Handle malformed or incomplete TLV data
  defp parse_subtlv_data(binary, acc) when is_binary(binary) and binary != <<>> do
    require Logger
    Logger.warning("Incomplete or malformed TLV data: #{byte_size(binary)} bytes remaining, data: #{inspect(binary, limit: 20)}")
    Enum.reverse(acc)
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

  # Helper function to determine if we should attempt compound parsing
  @spec should_attempt_compound_parsing?(map(), binary()) :: boolean()
  defp should_attempt_compound_parsing?(metadata, binary_value) when is_binary(binary_value) do
    # Compound TLV MUST have at least 3 bytes to contain a valid sub-TLV (type + length + minimal value)
    # Don't attempt compound parsing on values too small to contain sub-TLVs
    byte_size = byte_size(binary_value)
    if byte_size < 3 do
      false
    else
      # Attempt compound parsing if:
      # 1. TLV is known to support subtlvs in specs AND has sufficient data
      has_subtlv_support = Map.get(metadata, :subtlv_support, false) 
      
      # 2. OR explicitly marked as compound type AND has sufficient data
      is_compound_type = Map.get(metadata, :value_type) == :compound

      # 3. OR binary is long enough AND not an atomic type
      # But don't attempt for types that are definitely not compound (like frequency, boolean)
      value_type = Map.get(metadata, :value_type)
      has_atomic_type = value_type in [:frequency, :boolean, :ipv4, :ipv6, :mac_address, :duration, :percentage, :power_quarter_db]
      long_enough_for_subtlvs = byte_size >= 3

      # Parse as compound if explicitly supported, compound type, or long enough (unless it's an atomic type)
      (has_subtlv_support || is_compound_type || (long_enough_for_subtlvs && !has_atomic_type))
    end
  end

  # Guard clause for non-binary values (like ASN.1 parsed structures)
  defp should_attempt_compound_parsing?(_metadata, _non_binary_value), do: false
end
