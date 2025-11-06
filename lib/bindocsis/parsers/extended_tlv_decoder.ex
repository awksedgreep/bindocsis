defmodule Bindocsis.Parsers.ExtendedTlvDecoder do
  @moduledoc """
  Extended TLV decoder that handles both standard and extended length encoding
  for PacketCable MTA configuration files and DOCSIS files.

  Supports:
  - Standard length (0x00-0x7F): Direct length value
  - Extended length (0x80-0xFF): Length-of-length encoding
    - 0x81 XX: Length is in next 1 byte
    - 0x82 XX XX: Length is in next 2 bytes  
    - 0x83 XX XX XX: Length is in next 3 bytes
    - 0x84 XX XX XX XX: Length is in next 4 bytes
  """

  require Logger

  @doc """
  Decodes TLV binary data with support for extended length encoding.

  Returns {:ok, tlvs} or {:error, reason}
  """
  def decode(binary) when is_binary(binary) do
    try do
      tlvs = decode_tlvs(binary, [])
      {:ok, Enum.reverse(tlvs)}
    rescue
      e -> {:error, "TLV decode error: #{Exception.message(e)}"}
    catch
      {:invalid_tlv, reason} -> {:error, reason}
    end
  end

  # Base case: no more data
  defp decode_tlvs(<<>>, acc), do: acc

  # Not enough data for even type+length
  defp decode_tlvs(data, _acc) when byte_size(data) < 2 do
    throw(
      {:invalid_tlv, "Insufficient data for TLV header (need 2 bytes, have #{byte_size(data)})"}
    )
  end

  # Parse next TLV
  defp decode_tlvs(data, acc) do
    case parse_tlv(data) do
      {:ok, tlv, remaining} ->
        decode_tlvs(remaining, [tlv | acc])

      {:error, reason} ->
        throw({:invalid_tlv, reason})
    end
  end

  @doc """
  Parses a single TLV from the beginning of binary data.

  Returns {:ok, tlv_map, remaining_binary} or {:error, reason}
  """
  def parse_tlv(<<type::8, length_byte::8, rest::binary>>) do
    case decode_length(length_byte, rest) do
      {:ok, length, value_and_rest} ->
        if byte_size(value_and_rest) >= length do
          <<value::binary-size(length), remaining::binary>> = value_and_rest

          tlv = %{
            type: type,
            length: length,
            value: value,
            raw_length_encoding: length_byte
          }

          {:ok, tlv, remaining}
        else
          {:error,
           "Insufficient data for TLV value (need #{length} bytes, have #{byte_size(value_and_rest)})"}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  def parse_tlv(data) when byte_size(data) < 2 do
    {:error, "Insufficient data for TLV header"}
  end

  @doc """
  Decodes length field with support for extended length encoding.

  Length encoding rules:
  - 0x00-0x7F: Direct length value (0-127 bytes)
  - 0x80: Invalid (reserved)
  - 0x81: Length is in next 1 byte (128-255 bytes)
  - 0x82: Length is in next 2 bytes (256-65535 bytes)
  - 0x83: Length is in next 3 bytes
  - 0x84: Length is in next 4 bytes
  - 0x85-0xFF: Invalid (too many length bytes)
  """
  def decode_length(length_byte, remaining_data) do
    cond do
      # Standard short length (0-127)
      length_byte <= 0x7F ->
        {:ok, length_byte, remaining_data}

      # Reserved/invalid
      length_byte == 0x80 ->
        {:error, "Invalid length encoding 0x80 (reserved)"}

      # Extended length encoding
      length_byte >= 0x81 and length_byte <= 0x84 ->
        length_bytes_count = length_byte - 0x80
        decode_extended_length(length_bytes_count, remaining_data)

      # Too many length bytes
      length_byte > 0x84 ->
        {:error,
         "Invalid length encoding 0x#{Integer.to_string(length_byte, 16)} (too many length bytes)"}

      true ->
        {:error, "Unknown length encoding 0x#{Integer.to_string(length_byte, 16)}"}
    end
  end

  # Decode extended length based on number of length bytes
  defp decode_extended_length(num_bytes, data) when num_bytes > byte_size(data) do
    {:error,
     "Insufficient data for extended length (need #{num_bytes} bytes, have #{byte_size(data)})"}
  end

  # 1-byte extended length (0x81)
  defp decode_extended_length(1, <<length::8, rest::binary>>) do
    if length <= 0x7F do
      Logger.warning(
        "Extended length 0x81 used for short length #{length} (should use direct encoding)"
      )
    end

    {:ok, length, rest}
  end

  # 2-byte extended length (0x82)  
  defp decode_extended_length(2, <<length::16, rest::binary>>) do
    if length <= 0xFF do
      Logger.warning(
        "Extended length 0x82 used for length #{length} (could use shorter encoding)"
      )
    end

    {:ok, length, rest}
  end

  # 3-byte extended length (0x83)
  defp decode_extended_length(3, <<length::24, rest::binary>>) do
    if length <= 0xFFFF do
      Logger.warning(
        "Extended length 0x83 used for length #{length} (could use shorter encoding)"
      )
    end

    {:ok, length, rest}
  end

  # 4-byte extended length (0x84) - This is where the bug was happening
  defp decode_extended_length(4, <<length::32, rest::binary>>) do
    if length <= 0xFFFFFF do
      Logger.warning(
        "Extended length 0x84 used for length #{length} (could use shorter encoding)"
      )
    end

    # Sanity check for unreasonably large lengths
    if length > 100_000_000 do
      Logger.error(
        "Decoded extremely large length: #{length} bytes. This may indicate a parsing error or corrupted data."
      )

      Logger.error("Length bytes: #{inspect(<<length::32>>)}")

      # For PacketCable files, try alternative interpretations
      case try_alternative_length_decoding(<<length::32>>) do
        {:ok, alternative_length} ->
          Logger.info("Trying alternative length interpretation: #{alternative_length}")
          {:ok, alternative_length, rest}

        :error ->
          {:error, "Unreasonably large length: #{length} bytes (data may be corrupted)"}
      end
    else
      {:ok, length, rest}
    end
  end

  # Handle cases where we don't have enough bytes
  defp decode_extended_length(num_bytes, data) do
    {:error, "Need #{num_bytes} bytes for extended length, but only have #{byte_size(data)}"}
  end

  @doc """
  Try alternative length decoding schemes for PacketCable compatibility.

  Some PacketCable implementations might use different byte ordering
  or length calculation methods.
  """
  def try_alternative_length_decoding(<<b1, b2, b3, b4>>) do
    # Try little-endian interpretation
    little_endian = b4 * 0x1000000 + b3 * 0x10000 + b2 * 0x100 + b1

    # Try interpreting as separate length fields
    # Maybe it's: section_length(2) + data_length(2)
    section_len = b1 * 0x100 + b2
    data_len = b3 * 0x100 + b4

    # Try sum interpretation
    sum_interpretation = section_len + data_len

    # Try BCD or other encodings
    alternatives = [
      little_endian,
      section_len,
      data_len,
      sum_interpretation,
      # Maybe only the last byte matters
      b4
    ]

    # Return first reasonable alternative (< 10MB)
    reasonable = Enum.find(alternatives, &(&1 > 0 and &1 < 10_000_000))

    if reasonable do
      {:ok, reasonable}
    else
      :error
    end
  end

  @doc """
  Debug helper to analyze problematic length bytes
  """
  def debug_length_bytes(binary) when is_binary(binary) do
    case binary do
      <<type::8, 0x84, b1::8, b2::8, b3::8, b4::8, _rest::binary>> ->
        big_endian = b1 * 0x1000000 + b2 * 0x10000 + b3 * 0x100 + b4
        little_endian = b4 * 0x1000000 + b3 * 0x10000 + b2 * 0x100 + b1

        %{
          type: type,
          length_indicator: 0x84,
          length_bytes: [b1, b2, b3, b4],
          big_endian_length: big_endian,
          little_endian_length: little_endian,
          individual_bytes: %{b1: b1, b2: b2, b3: b3, b4: b4},
          hex_representation:
            "0x#{Integer.to_string(b1, 16)}#{Integer.to_string(b2, 16)}#{Integer.to_string(b3, 16)}#{Integer.to_string(b4, 16)}"
        }

      _ ->
        %{error: "Binary doesn't match expected 0x84 extended length pattern"}
    end
  end
end
