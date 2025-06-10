#!/usr/bin/env elixir

# Test alternative length parsing strategies for 0xFF issue
# Usage: elixir test_alternative_parsing.exs <file_path>

defmodule AlternativeTLVParser do
  require Logger

  def main([file_path]) do
    case File.read(file_path) do
      {:ok, binary} ->
        IO.puts("=== Alternative TLV Length Parsing Test ===")
        IO.puts("File: #{file_path}")
        IO.puts("Total size: #{byte_size(binary)} bytes")
        IO.puts("")
        
        find_problematic_tlv(binary)
        
      {:error, reason} ->
        IO.puts("Error reading file: #{reason}")
    end
  end

  def main([]) do
    IO.puts("Usage: elixir test_alternative_parsing.exs <file_path>")
    IO.puts("Example: elixir test_alternative_parsing.exs tmp/gunslinger/0015d13addf1.bin")
  end

  # Find the TLV with type 43 and 0xFF length
  def find_problematic_tlv(binary, offset \\ 0) do
    case find_tlv_43_with_ff(binary, offset) do
      {:found, tlv_offset, tlv_binary} ->
        IO.puts("Found problematic TLV at offset #{tlv_offset}")
        IO.puts("TLV data (first 32 bytes):")
        show_hex_dump(tlv_binary, 32)
        IO.puts("")
        
        test_alternative_parsings(tlv_binary, tlv_offset)
        
      :not_found ->
        IO.puts("No TLV with type 43 and 0xFF length found")
    end
  end

  defp find_tlv_43_with_ff(binary, offset) when byte_size(binary) >= 2 do
    case binary do
      <<43, 255, _rest::binary>> ->
        {:found, offset, binary}
        
      <<_type, length, rest::binary>> when length < 128 and byte_size(rest) >= length ->
        # Skip this TLV and continue
        <<_value::binary-size(length), next_binary::binary>> = rest
        find_tlv_43_with_ff(next_binary, offset + 2 + length)
        
      <<_type, _length, _rest::binary>> ->
        # Complex length encoding or insufficient data, move byte by byte
        <<_first_byte, remaining::binary>> = binary
        find_tlv_43_with_ff(remaining, offset + 1)
        
      _ ->
        :not_found
    end
  end
  
  defp find_tlv_43_with_ff(_binary, _offset), do: :not_found

  defp test_alternative_parsings(<<43, 255, rest::binary>>, offset) do
    IO.puts("Testing different interpretations of Type=43, Length=0xFF:")
    IO.puts("")
    
    # Strategy 1: Treat 0xFF as "next byte is length"
    test_strategy_1(rest, offset)
    
    # Strategy 2: Treat 0xFF as invalid/terminator
    test_strategy_2(rest, offset)
    
    # Strategy 3: Treat as vendor-specific format
    test_strategy_3(rest, offset)
    
    # Strategy 4: Check if previous parsing was misaligned
    test_strategy_4(rest, offset)
  end

  defp test_strategy_1(rest, offset) do
    IO.puts("📋 Strategy 1: 0xFF means 'next byte is length'")
    if byte_size(rest) >= 1 do
      <<length::8, value_data::binary>> = rest
      IO.puts("  Length from next byte: #{length}")
      if byte_size(value_data) >= length do
        <<actual_value::binary-size(length), _remaining::binary>> = value_data
        IO.puts("  ✅ This would give a TLV with #{length} bytes of value data")
        IO.puts("  Value (hex): #{format_hex(actual_value)}")
        IO.puts("  Value (ascii): #{inspect_as_ascii(actual_value)}")
      else
        IO.puts("  ❌ Insufficient data: need #{length} but have #{byte_size(value_data)}")
      end
    else
      IO.puts("  ❌ No data available for length byte")
    end
    IO.puts("")
  end

  defp test_strategy_2(rest, offset) do
    IO.puts("📋 Strategy 2: 0xFF is invalid/terminator")
    IO.puts("  This would mean the TLV is malformed or we hit a terminator")
    IO.puts("  Next bytes after 0xFF: #{format_hex(binary_take(rest, 16))}")
    IO.puts("  Could be start of next TLV or garbage data")
    IO.puts("")
  end

  defp test_strategy_3(rest, offset) do
    IO.puts("📋 Strategy 3: Vendor-specific format (Type 43)")
    IO.puts("  Vendor-specific TLVs might use different encoding")
    if byte_size(rest) >= 2 do
      <<first::8, second::8, value_rest::binary>> = rest
      # Try interpreting first two bytes as 16-bit length
      length_16 = (first * 256) + second
      IO.puts("  Interpreting next 2 bytes as 16-bit length: #{length_16}")
      if length_16 < 1000 and byte_size(value_rest) >= length_16 do
        <<vendor_value::binary-size(length_16), _remaining::binary>> = value_rest
        IO.puts("  ✅ This would give reasonable vendor data:")
        IO.puts("  Length: #{length_16} bytes")
        IO.puts("  Value (hex): #{format_hex(vendor_value)}")
        IO.puts("  Value (ascii): #{inspect_as_ascii(vendor_value)}")
      else
        IO.puts("  ❌ Still unrealistic length: #{length_16}")
      end
    end
    IO.puts("")
  end

  defp test_strategy_4(rest, offset) do
    IO.puts("📋 Strategy 4: Check for parsing misalignment")
    IO.puts("  Maybe we're not at a TLV boundary due to earlier error")
    IO.puts("  Looking for potential TLV patterns in next 20 bytes:")
    
    search_data = binary_take(rest, 20)
    for i <- 0..min(18, byte_size(search_data) - 2) do
      <<_skip::binary-size(i), potential_type::8, potential_length::8, _rest2::binary>> = search_data
      if potential_length < 128 and potential_length > 0 do
        IO.puts("    Offset +#{i}: Type=#{potential_type}, Length=#{potential_length} (reasonable)")
      end
    end
    IO.puts("")
  end

  defp show_hex_dump(binary, max_bytes) do
    data = binary_take(binary, max_bytes)
    hex_string = data
                 |> :binary.bin_to_list()
                 |> Enum.map(&Integer.to_string(&1, 16))
                 |> Enum.map(&String.pad_leading(&1, 2, "0"))
                 |> Enum.chunk_every(16)
                 |> Enum.map(&Enum.join(&1, " "))
                 |> Enum.join("\n")
    IO.puts(hex_string)
  end

  defp format_hex(binary) when byte_size(binary) <= 32 do
    binary
    |> :binary.bin_to_list()
    |> Enum.map(&Integer.to_string(&1, 16))
    |> Enum.map(&String.pad_leading(&1, 2, "0"))
    |> Enum.join(" ")
  end
  
  defp format_hex(binary) do
    first_16 = binary_take(binary, 16)
    format_hex(first_16) <> " ..."
  end

  defp inspect_as_ascii(binary) do
    binary
    |> :binary.bin_to_list()
    |> Enum.map(fn
      char when char >= 32 and char <= 126 -> char
      _ -> ?.
    end)
    |> List.to_string()
    |> String.slice(0, 32)
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
System.argv() |> AlternativeTLVParser.main()