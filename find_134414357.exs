#!/usr/bin/env elixir

# Script to find the exact byte pattern that produces the magic number 134414357

defmodule Find134414357 do
  import Bitwise
  
  def main do
    IO.puts """
    
    🔍 Finding the exact byte pattern that produces 134414357
    ══════════════════════════════════════════════════════════
    
    """
    
    target = 134414357
    IO.puts "Target number: #{target}"
    IO.puts "As hex: 0x#{Integer.to_string(target, 16)}"
    IO.puts "As bytes: #{inspect(<<target::32>>, binaries: :as_binaries)}"
    
    # Test the legacy formula: ((first_byte & 0x7F) << 8) + second_byte
    IO.puts "\n🧮 Testing legacy formula: ((first_byte & 0x7F) << 8) + second_byte"
    
    # The legacy code triggers when first_byte is 128-253 and NOT 0x81, 0x82, 0x84
    problematic_first_bytes = 128..253 
      |> Enum.to_list() 
      |> Enum.reject(&(&1 in [0x81, 0x82, 0x84]))
    
    found_patterns = []
    
    for first_byte <- problematic_first_bytes,
        second_byte <- 0..255 do
      
      calculated = ((first_byte &&& 0x7F) <<< 8) + second_byte
      
      if calculated == target do
        pattern = {first_byte, second_byte}
        found_patterns = [pattern | found_patterns]
        
        IO.puts "🎯 MATCH FOUND!"
        IO.puts "  first_byte: #{first_byte} (0x#{Integer.to_string(first_byte, 16)})"
        IO.puts "  second_byte: #{second_byte} (0x#{Integer.to_string(second_byte, 16)})"
        IO.puts "  Calculation: ((#{first_byte} & 0x7F) << 8) + #{second_byte}"
        IO.puts "  = ((#{first_byte &&& 0x7F}) << 8) + #{second_byte}"
        IO.puts "  = #{(first_byte &&& 0x7F) <<< 8} + #{second_byte}"
        IO.puts "  = #{calculated}"
        
        # Create the actual byte pattern that would trigger this
        test_pattern = <<first_byte, second_byte, 0x01, 0x02, 0x03>>
        IO.puts "  Test pattern: #{inspect(test_pattern, binaries: :as_binaries)}"
        
        # Test this pattern
        test_parse_pattern(test_pattern)
      end
    end
    
    if Enum.empty?(found_patterns) do
      IO.puts "❌ No patterns found that produce exactly 134414357 with legacy formula"
      
      # Let's try to understand where 134414357 might come from
      analyze_number_composition(target)
    else
      IO.puts "\n✅ Found #{length(found_patterns)} pattern(s) that produce 134414357"
    end
    
    # Also test some real-world patterns that might be in MTA files
    IO.puts "\n🏃 Testing realistic MTA file patterns:"
    test_realistic_mta_patterns()
  end
  
  defp test_parse_pattern(pattern) do
    try do
      case Bindocsis.parse(pattern, format: :binary) do
        {:ok, tlvs} ->
          IO.puts "    ✅ Parsed successfully: #{length(tlvs)} TLVs"
          
        {:error, reason} ->
          IO.puts "    ❌ Parse error: #{reason}"
          if String.contains?(reason, "134414357") do
            IO.puts "    🎯 CONFIRMED: This pattern produces the magic number!"
          end
      end
    rescue
      error ->
        IO.puts "    💥 Exception: #{Exception.message(error)}"
    end
  end
  
  defp analyze_number_composition(target) do
    IO.puts "\n🔬 Analyzing number composition:"
    
    # Break down the number in different ways
    <<b1, b2, b3, b4>> = <<target::32>>
    IO.puts "As 4 bytes: [#{b1}, #{b2}, #{b3}, #{b4}]"
    
    # Check if it could be from a different length calculation
    IO.puts "\nPossible sources:"
    
    # Could it be from a 4-byte big-endian read?
    IO.puts "If read as 4-byte big-endian: #{b1} #{b2} #{b3} #{b4}"
    
    # Could it be from extended length with different byte count?
    for num_bytes <- 1..4 do
      if num_bytes <= 4 do
        bytes = Enum.take([b1, b2, b3, b4], num_bytes)
        reconstructed = bytes |> Enum.reduce(0, fn byte, acc -> (acc <<< 8) + byte end)
        IO.puts "#{num_bytes} bytes #{inspect(bytes)}: #{reconstructed}"
      end
    end
    
    # Test if any of these interpretations match
    test_bytes = [b1, b2, b3, b4]
    test_patterns = [
      # Pattern where the bytes appear in sequence in a TLV
      [0x03, 0x01, 0x01] ++ test_bytes,
      [0x45, 0x84] ++ test_bytes ++ [0x01, 0x02],  # TLV 69 with 4-byte length
      [0x40, 0x84] ++ test_bytes ++ [0x01],         # TLV 64 with 4-byte length
    ]
    
    IO.puts "\n🧪 Testing reconstructed patterns:"
    Enum.with_index(test_patterns, 1) |> Enum.each(fn {pattern, i} ->
      binary_pattern = :binary.list_to_bin(pattern)
      IO.puts "Pattern #{i}: #{inspect(binary_pattern, binaries: :as_binaries)}"
      test_parse_pattern(binary_pattern)
    end)
  end
  
  defp test_realistic_mta_patterns do
    # Create patterns that might appear in real MTA files
    patterns = [
      # Pattern 1: MTA with Kerberos realm having large content
      <<0x03, 0x01, 0x01, 0x45, 0x85, 0x08, 0x03, 0x00, 0x15, "test">>,
      
      # Pattern 2: MTA Configuration File with large nested content  
      <<0x40, 0x85, 0x08, 0x03, 0x00, 0x15, 0x45, 0x05, "realm">>,
      
      # Pattern 3: Direct problem bytes in sequence
      <<0x08, 0x03, 0x00, 0x15>>,
      
      # Pattern 4: Extended length that might be misinterpreted
      <<0x45, 0x83, 0x08, 0x03, 0x00, 0x15, 0x01, 0x02>>,
      
      # Pattern 5: Another TLV type with the problem bytes
      <<0x46, 0x84, 0x08, 0x03, 0x00, 0x15, 0x01>>,
    ]
    
    Enum.with_index(patterns, 1) |> Enum.each(fn {pattern, i} ->
      IO.puts "\nRealistic pattern #{i}: #{inspect(pattern, binaries: :as_binaries)}"
      test_parse_pattern(pattern)
    end)
  end
end

Find134414357.main()