defmodule Bindocsis.Parsers.MtaBinaryParser do
  @moduledoc """
  Specialized binary parser for PacketCable MTA configuration files.
  
  This parser addresses the specific issue where TLV type 0x84 (Line Package)
  was being misinterpreted as an extended length indicator, causing massive
  length values and parsing failures.
  
  Key differences from standard TLV parsing:
  - Smarter detection of when 0x8X bytes are TLV types vs length indicators
  - PacketCable-specific TLV type validation
  - Context-aware parsing that prefers reasonable interpretations
  """

  alias Bindocsis.MtaSpecs
  require Logger

  @type tlv :: %{
    type: non_neg_integer(),
    length: non_neg_integer(),
    value: binary(),
    raw_value: binary()
  }

  @doc """
  Parses MTA binary configuration data into TLV structures.
  
  Returns {:ok, tlvs} or {:error, reason}
  """
  @spec parse(binary()) :: {:ok, [tlv()]} | {:error, String.t()}
  def parse(binary) when is_binary(binary) do
    try do
      tlvs = parse_tlvs(binary, [])
      {:ok, Enum.reverse(tlvs)}
    rescue
      e -> {:error, "MTA binary parse error: #{Exception.message(e)}"}
    catch
      {:parse_error, reason} -> {:error, reason}
    end
  end

  # Base case: no more data
  defp parse_tlvs(<<>>, acc), do: acc
  
  # Insufficient data for TLV header
  defp parse_tlvs(data, _acc) when byte_size(data) < 2 do
    throw({:parse_error, "Insufficient data for TLV header (need 2 bytes, have #{byte_size(data)})"})
  end

  # Parse the next TLV
  defp parse_tlvs(data, acc) do
    case parse_single_tlv(data) do
      {:ok, tlv, remaining} ->
        parse_tlvs(remaining, [tlv | acc])
      {:error, reason} ->
        throw({:parse_error, reason})
    end
  end

  @doc """
  Parses a single TLV from the beginning of binary data.
  
  This function implements smart logic to distinguish between:
  1. Extended length encoding (0x8X as length indicator)
  2. PacketCable TLV types (0x84 as "Line Package" type)
  """
  @spec parse_single_tlv(binary()) :: {:ok, tlv(), binary()} | {:error, String.t()}
  def parse_single_tlv(<<type::8, length_byte::8, rest::binary>>) do
    cond do
      # Standard length (0-127 bytes)
      length_byte <= 0x7F ->
        parse_with_standard_length(type, length_byte, rest)
      
      # Potential extended length (128-255)
      length_byte >= 0x80 ->
        # This is where the magic happens - we need to decide if this is
        # extended length encoding or if it's actually the next TLV type
        handle_potential_extended_length(type, length_byte, rest)
    end
  end

  def parse_single_tlv(data) when byte_size(data) < 2 do
    {:error, "Insufficient data for TLV header"}
  end

  # Handle standard length encoding
  defp parse_with_standard_length(type, length, rest) do
    if byte_size(rest) >= length do
      <<value::binary-size(length), remaining::binary>> = rest
      tlv = create_tlv(type, length, value)
      {:ok, tlv, remaining}
    else
      {:error, "Insufficient data for TLV value (need #{length} bytes, have #{byte_size(rest)})"}
    end
  end

  # Handle potential extended length - this is the key fix
  defp handle_potential_extended_length(type, potential_length_byte, rest) do
    # Special handling for 0x84: In PacketCable context, this is almost always
    # TLV type 84 "Line Package" rather than extended length encoding
    cond do
      potential_length_byte == 0x84 and byte_size(rest) >= 1 ->
        # Look at the next byte - if it's a reasonable length (< 128), treat 0x84 as TLV type
        case rest do
          <<next_byte::8, _::binary>> when next_byte <= 0x7F ->
            Logger.info("Interpreting 0x84 as PacketCable TLV type 84 'Line Package', not extended length")
            # Current TLV has zero length, 0x84 starts new TLV
            tlv = create_tlv(type, 0, <<>>)
            remaining = <<potential_length_byte::8, rest::binary>>
            {:ok, tlv, remaining}
          
          _ ->
            # Next byte suggests extended length, proceed with that interpretation
            parse_with_extended_length(type, potential_length_byte, rest)
        end
    
      # For other 0x8X bytes, use heuristics
      is_valid_packetcable_tlv_type?(potential_length_byte) and 
      looks_like_new_tlv_sequence?(potential_length_byte, rest) ->
        Logger.info("Interpreting 0x#{Integer.to_string(potential_length_byte, 16)} as TLV type, not extended length")
        
        # Treat potential_length_byte as the start of a new TLV
        # This means the current TLV (type) has zero length
        tlv = create_tlv(type, 0, <<>>)
        remaining = <<potential_length_byte::8, rest::binary>>
        {:ok, tlv, remaining}
        
      true ->
        # Default to extended length parsing
        parse_with_extended_length(type, potential_length_byte, rest)
    end
  end

  # Parse using extended length encoding
  defp parse_with_extended_length(type, length_indicator, rest) do
    case decode_extended_length(length_indicator, rest) do
      {:ok, length, value_data} ->
        if byte_size(value_data) >= length do
          <<value::binary-size(length), remaining::binary>> = value_data
          
          # Sanity check for unreasonably large lengths in MTA files
          if length > 10_000 do
            Logger.warning("Very large TLV length #{length} for type #{type} - may indicate parsing error")
          end
          
          tlv = create_tlv(type, length, value)
          {:ok, tlv, remaining}
        else
          {:error, "Insufficient data for extended TLV value (need #{length} bytes, have #{byte_size(value_data)})"}
        end
      
      {:error, reason} ->
        {:error, "Extended length parsing failed: #{reason}"}
    end
  end

  # Check if a byte could be a valid PacketCable TLV type
  defp is_valid_packetcable_tlv_type?(byte) do
    # Check against known PacketCable TLV types
    case MtaSpecs.get_tlv_info(byte, "2.0") do
      {:ok, _} -> true
      {:error, _} -> false
    end
  end

  # Heuristic to determine if a sequence looks like a new TLV
  defp looks_like_new_tlv_sequence?(potential_type, <<potential_length::8, rest::binary>>) do
    # A sequence looks like a TLV if:
    # 1. The potential_type is a known PacketCable TLV
    # 2. The potential_length is reasonable (< 128 for simple case)
    # 3. There's enough data for the claimed length
    
    is_valid_packetcable_tlv_type?(potential_type) and
    potential_length <= 0x7F and
    byte_size(rest) >= potential_length
  end

  defp looks_like_new_tlv_sequence?(_potential_type, _insufficient_data), do: false

  # Decode extended length encoding
  defp decode_extended_length(length_indicator, data) do
    case length_indicator do
      0x80 ->
        {:error, "Invalid extended length indicator 0x80 (reserved)"}
      
      0x81 ->
        case data do
          <<length::8, rest::binary>> -> {:ok, length, rest}
          _ -> {:error, "Insufficient data for 1-byte extended length"}
        end
      
      0x82 ->
        case data do
          <<length::16, rest::binary>> -> {:ok, length, rest}
          _ -> {:error, "Insufficient data for 2-byte extended length"}
        end
      
      0x83 ->
        case data do
          <<length::24, rest::binary>> -> {:ok, length, rest}
          _ -> {:error, "Insufficient data for 3-byte extended length"}
        end
      
      0x84 ->
        case data do
          <<length::32, rest::binary>> ->
            # Extra validation for 4-byte lengths in MTA context
            if length > 10_000 do
              {:error, "Unreasonably large 4-byte length: #{length} (likely parsing error - 0x84 may be TLV type)"}
            else
              {:ok, length, rest}
            end
          _ -> 
            {:error, "Insufficient data for 4-byte extended length"}
        end
      
      _ ->
        {:error, "Invalid extended length indicator 0x#{Integer.to_string(length_indicator, 16)}"}
    end
  end

  # Create a TLV struct with PacketCable-specific information
  defp create_tlv(type, length, value) do
    %{
      type: type,
      length: length,
      value: value,
      raw_value: value,
      name: MtaSpecs.get_tlv_name(type, "2.0"),
      description: MtaSpecs.get_tlv_description(type, "2.0"),
      mta_specific: MtaSpecs.mta_specific?(type)
    }
  end

  @doc """
  Debug helper to analyze the first few TLVs in an MTA binary file.
  """
  @spec debug_parse(binary(), integer()) :: map()
  def debug_parse(binary, max_tlvs \\ 5) do
    result = %{
      file_size: byte_size(binary),
      hex_dump: binary |> binary_part(0, min(32, byte_size(binary))) |> format_hex(),
      parse_attempts: [],
      status: :unknown,
      tlvs_parsed: 0,
      first_tlvs: [],
      error: nil
    }

    # Try parsing with our smart parser
    case parse(binary) do
      {:ok, tlvs} ->
        limited_tlvs = Enum.take(tlvs, max_tlvs)
        %{result | 
          status: :success,
          tlvs_parsed: length(tlvs),
          first_tlvs: limited_tlvs
        }
      
      {:error, reason} ->
        %{result |
          status: :error,
          error: reason
        }
    end
  end

  # Format binary as hex string
  defp format_hex(binary) do
    binary
    |> :binary.bin_to_list()
    |> Enum.map(&Integer.to_string(&1, 16))
    |> Enum.map(&String.pad_leading(&1, 2, "0"))
    |> Enum.join(" ")
    |> String.upcase()
  end
end