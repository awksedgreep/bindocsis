#!/usr/bin/env elixir

# Simple debug script to investigate the 134414357 length parsing bug

defmodule SimpleLengthDebugger do
  def main do
    IO.puts "🔍 Debugging the 134414357 length parsing bug"
    IO.puts "=" |> String.duplicate(50)
    
    # The magic number that keeps appearing
    magic = 134414357
    IO.puts "Magic number: #{magic}"
    IO.puts "As hex: 0x#{Integer.to_string(magic, 16)}"
    
    # Convert to bytes to see the pattern
    <<b1, b2, b3, b4>> = <<magic::32>>
    IO.puts "As 4 bytes: #{b1}, #{b2}, #{b3}, #{b4}"
    IO.puts "As hex bytes: 0x#{Integer.to_string(b1, 16)}, 0x#{Integer.to_string(b2, 16)}, 0x#{Integer.to_string(b3, 16)}, 0x#{Integer.to_string(b4, 16)}"
    
    # The hex is 0x08050505 - this suggests bytes [8, 5, 5, 5]
    # Let's create test patterns with these bytes
    
    IO.puts "\n🧪 Testing problematic patterns:"
    
    test_patterns = [
      # Pattern 1: Direct bytes that could be misinterpreted
      <<0x08, 0x05, 0x05, 0x05>>,
      
      # Pattern 2: TLV with extended length
      <<0x45, 0x83, 0x08, 0x05, 0x05, 0x01, 0x02>>,  # TLV 69, 3-byte length
      
      # Pattern 3: Another variant 
      <<0x03, 0x01, 0x01, 0x45, 0x83, 0x08, 0x05, 0x05>>,
      
      # Pattern 4: Real-world looking pattern
      <<0x03, 0x01, 0x01, 0x40, 0x85, 0x08, 0x05, 0x05, 0x05, 0x01>>,
    ]
    
    Enum.with_index(test_patterns, 1) |> Enum.each(fn {pattern, i} ->
      IO.puts "\nPattern #{i}: #{inspect(pattern, binaries: :as_binaries)}"
      test_pattern(pattern)
    end)
    
    IO.puts "\n🔧 Manual parsing analysis:"
    analyze_manual_parsing(<<0x45, 0x83, 0x08, 0x05, 0x05, 0x01, 0x02>>)
  end
  
  defp test_pattern(data) do
    try do
      case Bindocsis.parse(data, format: :binary) do
        {:ok, tlvs} ->
          IO.puts "  ✅ Success: #{length(tlvs)} TLVs"
          
        {:error, reason} ->
          IO.puts "  ❌ Error: #{reason}"
          if String.contains?(reason, "134414357") do
            IO.puts "  🎯 MAGIC NUMBER FOUND!"
          end
      end
    rescue
      error ->
        IO.puts "  💥 Exception: #{Exception.message(error)}"
    end
  end
  
  defp analyze_manual_parsing(data) do
    IO.puts "Analyzing: #{inspect(data, binaries: :as_binaries)}"
    
    case data do
      <<type, length_byte, rest::binary>> ->
        IO.puts "Type: #{type}"
        IO.puts "Length byte: #{length_byte} (0x#{Integer.to_string(length_byte, 16)})"
        
        if length_byte >= 128 do
          num_length_bytes = length_byte - 128
          IO.puts "Extended length: #{num_length_bytes} bytes to follow"
          
          if byte_size(rest) >= num_length_bytes do
            <<length_data::size(num_length_bytes)-binary, _value::binary>> = rest
            decoded = :binary.decode_unsigned(length_data, :big)
            
            IO.puts "Length bytes: #{inspect(length_data, binaries: :as_binaries)}"
            IO.puts "Decoded length: #{decoded}"
            
            if decoded == 134414357 do
              IO.puts "🎯 REPRODUCED THE BUG!"
              
              # Show what might be going wrong
              IO.puts "Analysis:"
              IO.puts "  Length indicator: #{length_byte} (should be 128 + #{num_length_bytes})"
              IO.puts "  Expected: #{128 + num_length_bytes}"
              IO.puts "  Actual calculation may be wrong"
              
              # Test if it's a bit manipulation error
              Enum.each(length_data |> :binary.bin_to_list, fn byte ->
                IO.puts "  Byte: #{byte} (0x#{Integer.to_string(byte, 16)})"
              end)
            end
          end
        else
          IO.puts "Single byte length: #{length_byte}"
        end
        
      _ ->
        IO.puts "Insufficient data"
    end
  end
end

SimpleLengthDebugger.main()