#!/usr/bin/env elixir

# Debug script for TLV length parsing issues
# Usage: elixir debug_length_parsing.exs <file_path>

defmodule TLVDebugger do
  require Logger

  def main([file_path]) do
    case File.read(file_path) do
      {:ok, binary} ->
        IO.puts("=== TLV Length Parsing Debug ===")
        IO.puts("File: #{file_path}")
        IO.puts("Total size: #{byte_size(binary)} bytes")
        IO.puts("")
        
        debug_parse(binary, 0)
        
      {:error, reason} ->
        IO.puts("Error reading file: #{reason}")
    end
  end

  def main([]) do
    IO.puts("Usage: elixir debug_length_parsing.exs <file_path>")
    IO.puts("Example: elixir debug_length_parsing.exs tmp/gunslinger/config.cm")
  end

  def debug_parse(binary, offset \\ 0, max_tlvs \\ 50)
  def debug_parse(<<>>, _offset, _max_tlvs), do: IO.puts("=== End of data ===")
  def debug_parse(_binary, _offset, 0), do: IO.puts("=== Reached max TLVs limit ===")

  def debug_parse(binary, offset, max_tlvs) when byte_size(binary) >= 2 do
    <<type::8, first_length_byte::8, rest::binary>> = binary
    
    IO.puts("--- TLV at offset #{offset} ---")
    IO.puts("Type: #{type} (0x#{Integer.to_string(type, 16) |> String.pad_leading(2, "0")})")
    IO.puts("First length byte: #{first_length_byte} (0x#{Integer.to_string(first_length_byte, 16) |> String.pad_leading(2, "0")})")
    
    # Show hex dump of next 32 bytes for context
    context_bytes = binary_take(binary, 32)
    hex_dump = context_bytes 
                |> :binary.bin_to_list()
                |> Enum.map(&Integer.to_string(&1, 16))
                |> Enum.map(&String.pad_leading(&1, 2, "0"))
                |> Enum.join(" ")
    IO.puts("Hex context (32 bytes): #{hex_dump}")
    
    case debug_extract_length(first_length_byte, rest) do
      {:ok, actual_length, remaining_after_length} ->
        IO.puts("✅ Parsed length: #{actual_length} bytes")
        IO.puts("Remaining data after length: #{byte_size(remaining_after_length)} bytes")
        
        if byte_size(remaining_after_length) >= actual_length do
          IO.puts("✅ Sufficient data available")
          
          # Skip this TLV and continue
          <<_value::binary-size(actual_length), next_binary::binary>> = remaining_after_length
          next_offset = offset + 2 + length_bytes_used(first_length_byte) + actual_length
          debug_parse(next_binary, next_offset, max_tlvs - 1)
        else
          IO.puts("❌ INSUFFICIENT DATA: need #{actual_length} but only have #{byte_size(remaining_after_length)}")
          IO.puts("This is likely where the parsing error occurs!")
          
          # Show detailed analysis
          analyze_length_encoding(first_length_byte, rest)
        end
        
      {:error, reason} ->
        IO.puts("❌ Length parsing error: #{reason}")
        analyze_length_encoding(first_length_byte, rest)
    end
    
    IO.puts("")
  end

  def debug_parse(binary, offset, _max_tlvs) do
    IO.puts("--- Insufficient data at offset #{offset} ---")
    IO.puts("Remaining bytes: #{byte_size(binary)}")
    if byte_size(binary) > 0 do
      hex_dump = binary 
                  |> :binary.bin_to_list()
                  |> Enum.map(&Integer.to_string(&1, 16))
                  |> Enum.map(&String.pad_leading(&1, 2, "0"))
                  |> Enum.join(" ")
      IO.puts("Hex dump: #{hex_dump}")
    end
  end

  defp debug_extract_length(first_byte, rest) do
    cond do
      # Standard single-byte length
      first_byte < 128 ->
        {:ok, first_byte, rest}

      # Multi-byte length encoding (modern format)
      first_byte == 0x81 && byte_size(rest) >= 1 ->
        <<length::8, remaining::binary>> = rest
        {:ok, length, remaining}

      first_byte == 0x82 && byte_size(rest) >= 2 ->
        <<length::16, remaining::binary>> = rest
        {:ok, length, remaining}

      first_byte == 0x84 && byte_size(rest) >= 4 ->
        <<length::32, remaining::binary>> = rest
        {:ok, length, remaining}

      # Legacy support for old encoding
      first_byte >= 128 && first_byte < 254 && byte_size(rest) >= 1 ->
        <<second_byte::8, remaining::binary>> = rest
        # This is the problematic calculation
        actual_length = (Bitwise.band(first_byte, 0x7F) |> Bitwise.bsl(8)) + second_byte
        {:ok, actual_length, remaining}

      # Length spans multiple bytes (special marker)
      first_byte == 254 && byte_size(rest) >= 2 ->
        <<len_bytes::16, remaining::binary>> = rest
        {:ok, len_bytes, remaining}

      # 0xFF means next byte is the actual length
      first_byte == 255 && byte_size(rest) >= 1 ->
        <<length::8, remaining::binary>> = rest
        {:ok, length, remaining}

      true ->
        {:error, "Invalid multi-byte length format"}
    end
  end

  defp analyze_length_encoding(first_byte, rest) do
    IO.puts("\n=== DETAILED LENGTH ANALYSIS ===")
    IO.puts("First byte: #{first_byte} (0x#{Integer.to_string(first_byte, 16)})")
    IO.puts("Binary: #{Integer.to_string(first_byte, 2) |> String.pad_leading(8, "0")}")
    
    cond do
      first_byte < 128 ->
        IO.puts("✅ Single-byte length: #{first_byte}")
        
      first_byte == 0x81 ->
        if byte_size(rest) >= 1 do
          <<length::8, _::binary>> = rest
          IO.puts("✅ 0x81 format: next byte is #{length}")
        else
          IO.puts("❌ 0x81 format but no next byte available")
        end
        
      first_byte == 0x82 ->
        if byte_size(rest) >= 2 do
          <<length::16, _::binary>> = rest
          IO.puts("✅ 0x82 format: next 2 bytes are #{length}")
        else
          IO.puts("❌ 0x82 format but insufficient bytes available")
        end
        
      first_byte >= 128 && first_byte < 254 ->
        if byte_size(rest) >= 1 do
          <<second_byte::8, _::binary>> = rest
          # Show the problematic calculation step by step
          masked = Bitwise.band(first_byte, 0x7F)
          shifted = Bitwise.bsl(masked, 8)
          result = shifted + second_byte
          
          IO.puts("🔍 Legacy encoding calculation:")
          IO.puts("  first_byte & 0x7F = #{first_byte} & 127 = #{masked}")
          IO.puts("  masked << 8 = #{masked} << 8 = #{shifted}")
          IO.puts("  shifted + second_byte = #{shifted} + #{second_byte} = #{result}")
          IO.puts("  ❌ This gives unrealistic length: #{result}")
          
          # Alternative interpretations
          IO.puts("\n🔍 Alternative interpretations:")
          IO.puts("  Just second_byte: #{second_byte}")
          IO.puts("  first_byte + second_byte: #{first_byte + second_byte}")
          IO.puts("  (first_byte - 128) + second_byte: #{first_byte - 128 + second_byte}")
        else
          IO.puts("❌ Legacy format but no second byte available")
        end
        
      true ->
        IO.puts("❓ Unknown length encoding format")
    end
  end

  defp length_bytes_used(first_byte) do
    cond do
      first_byte < 128 -> 0
      first_byte == 0x81 -> 1
      first_byte == 0x82 -> 2
      first_byte == 0x84 -> 4
      first_byte >= 128 && first_byte < 254 -> 1
      first_byte == 254 -> 2
      first_byte == 255 -> 4
      true -> 0
    end
  end

  defp binary_take(binary, n) do
    if byte_size(binary) <= n do
      binary
    else
      <<result::binary-size(n), _::binary>> = binary
      result
    end
  end
end

# Handle command line arguments
System.argv() |> TLVDebugger.main()