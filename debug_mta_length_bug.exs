#!/usr/bin/env elixir

# Debug script to reproduce and fix the 134414357 length parsing bug in MTA files
# This bug seems to occur when parsing binary TLV files where length calculation goes wrong

defmodule MTALengthBugDebugger do
  require Logger

  def main do
    IO.puts """
    
    ╔══════════════════════════════════════════════════════════════════════════════╗
    ║                    MTA Length Parsing Bug Debugger                          ║
    ║                  Investigating the 134414357 issue                          ║
    ╚══════════════════════════════════════════════════════════════════════════════╝
    
    """

    # Test various scenarios that might trigger the bug
    test_suspicious_patterns()
    test_length_encoding_edge_cases()
    test_mta_specific_patterns()
    analyze_134414357_number()
    test_actual_parsing_logic()
  end

  def test_suspicious_patterns do
    IO.puts "🔍 Testing Suspicious Byte Patterns"
    IO.puts "=" |> String.duplicate(50)
    
    # The magic number that keeps appearing: 134414357
    # Let's see what bytes would produce this
    magic_number = 134414357
    IO.puts "Magic number: #{magic_number}"
    IO.puts "As hex: 0x#{Integer.to_string(magic_number, 16)}"
    IO.puts "As binary: #{Integer.to_string(magic_number, 2)}"
    
    # Break it down into bytes
    <<b1, b2, b3, b4>> = <<magic_number::32>>
    IO.puts "As 4 bytes: #{b1} #{b2} #{b3} #{b4} (0x#{Integer.to_string(b1, 16)} 0x#{Integer.to_string(b2, 16)} 0x#{Integer.to_string(b3, 16)} 0x#{Integer.to_string(b4, 16)})"
    
    # Test patterns that might produce this number
    test_patterns = [
      # Potential problematic patterns
      <<0x08, 0x05, 0x05, 0x05>>,  # Type 8, then bytes that might be misinterpreted
      <<0x45, 0x80, 0x05, 0x05>>,  # Extended length with high bit
      <<0xFF, 0x08, 0x05, 0x05>>,  # 255 extended length prefix
      <<0x80, 0x08, 0x05, 0x05>>,  # Length with high bit set
      <<0x05, 0x80, 0x05, 0x05>>,  # Another variant
      <<0x05, 0x08, 0x05, 0x05>>,  # Standard encoding
    ]
    
    Enum.each(test_patterns, fn pattern ->
      IO.puts "\nTesting pattern: #{inspect(pattern, binaries: :as_binaries)}"
      test_parse_pattern(pattern)
    end)
    
    IO.puts "\n"
  end

  def test_length_encoding_edge_cases do
    IO.puts "📏 Testing Length Encoding Edge Cases"
    IO.puts "=" |> String.duplicate(50)
    
    # Test different length encodings that might be misinterpreted
    test_cases = [
      # Standard single-byte lengths
      {<<0x03, 0x01, 0x01>>, "Standard: Type 3, Length 1, Value 1"},
      {<<0x03, 0x05, 0x01, 0x02, 0x03, 0x04, 0x05>>, "Standard: Type 3, Length 5"},
      
      # Extended length (length >= 128)
      {<<0x03, 0x81, 0x05, 0x01, 0x02, 0x03, 0x04, 0x05>>, "Extended: Type 3, Length 0x81,0x05 = 5"},
      {<<0x03, 0x80, 0x05, 0x01, 0x02, 0x03, 0x04, 0x05>>, "Extended: Type 3, Length 0x80,0x05 = 5"},
      
      # Cases that might trigger the bug
      {<<0x03, 0x85, 0x05, 0x05, 0x01, 0x02, 0x03>>, "Suspicious: Type 3, Length 0x85,0x05"},
      {<<0x08, 0x80, 0x05, 0x05, 0x01, 0x02, 0x03>>, "Suspicious: Type 8, Length 0x80,0x05"},
      {<<0x45, 0x80, 0x05, 0x05, 0x01, 0x02, 0x03>>, "Suspicious: Type 69, Length 0x80,0x05"},
      
      # Multi-byte length encodings
      {<<0x03, 0x82, 0x01, 0x00, 0x01>>, "2-byte length: Type 3, Length 0x82,0x01,0x00 = 256"},
      {<<0x03, 0x83, 0x08, 0x05, 0x05, 0x01>>, "3-byte length: Type 3, Length 0x83,0x08,0x05,0x05"},
    ]
    
    Enum.each(test_cases, fn {data, description} ->
      IO.puts "\n#{description}"
      IO.puts "Data: #{inspect(data, binaries: :as_binaries)}"
      test_parse_pattern(data)
    end)
    
    IO.puts "\n"
  end

  def test_mta_specific_patterns do
    IO.puts "📞 Testing MTA-Specific Patterns"
    IO.puts "=" |> String.duplicate(50)
    
    # Create patterns that look like real MTA TLVs
    mta_patterns = [
      # TLV 64 (MTA Configuration File) - compound TLV
      {<<64, 0x10, 65, 0x05, 66, 0x03, "sip", 69, 0x04, "test">>, "MTA Config with Voice TLVs"},
      
      # TLV 69 (Kerberos Realm) - string TLV  
      {<<69, 0x15, "PACKETCABLE.TEST.COM">>, "Kerberos Realm TLV"},
      
      # TLV 78 (MTA MAC Address) - MAC TLV
      {<<78, 0x06, 0x00, 0x11, 0x22, 0x33, 0x44, 0x55>>, "MTA MAC Address TLV"},
      
      # Potential problematic pattern from real files
      {<<0x03, 0x01, 0x01, 0x45, 0x80, 0x05, 0x05>>, "Real-world pattern that might trigger bug"},
      
      # Pattern that produces the magic number when misinterpreted
      create_pattern_for_magic_number(),
    ]
    
    Enum.each(mta_patterns, fn {data, description} ->
      IO.puts "\n#{description}"
      IO.puts "Data: #{inspect(data, binaries: :as_binaries)}"
      test_parse_pattern(data)
    end)
    
    IO.puts "\n"
  end

  def analyze_134414357_number do
    IO.puts "🔢 Analyzing the Magic Number: 134414357"
    IO.puts "=" |> String.duplicate(50)
    
    magic = 134414357
    
    # Try to reverse-engineer what bytes could produce this
    IO.puts "Decimal: #{magic}"
    IO.puts "Hex: 0x#{Integer.to_string(magic, 16)}"
    IO.puts "Binary: #{Integer.to_string(magic, 2)}"
    
    # Check if it's a result of bit shifting operations
    IO.puts "\nPossible interpretations:"
    
    # Common bit operations that might go wrong
    <<b1, b2, b3, b4>> = <<magic::32>>
    IO.puts "As 4 bytes: [#{b1}, #{b2}, #{b3}, #{b4}]"
    
    # Check if it matches common length encoding mistakes
    IO.puts "\nPossible length encoding mistakes:"
    
    # Mistake 1: Treating a multi-byte value as big-endian when it should be different
    reversed = <<b4, b3, b2, b1>> |> :binary.decode_unsigned(:big)
    IO.puts "Byte-reversed: #{reversed}"
    
    # Mistake 2: Wrong bit shifting
    for shift <- [8, 16, 24] do
      shifted = magic >>> shift
      IO.puts "Right-shifted by #{shift}: #{shifted}"
    end
    
    # Mistake 3: Check if it's related to extended length encoding  
    # In TLV, extended length uses: 0x8X followed by X bytes
    # If 0x85 0x05 0x05 is misinterpreted...
    test_combinations = [
      {0x85, 0x05, 0x05, 0x05},
      {0x80, 0x08, 0x05, 0x05}, 
      {0x08, 0x05, 0x05, 0x05},
    ]
    
    Enum.each(test_combinations, fn {a, b, c, d} ->
      combined = (a <<< 24) + (b <<< 16) + (c <<< 8) + d
      if combined == magic do
        IO.puts "⚡ MATCH FOUND: #{a} #{b} #{c} #{d} = #{combined}"
      else
        IO.puts "Testing: #{a} #{b} #{c} #{d} = #{combined}"
      end
    end)
    
    IO.puts "\n"
  end

  def test_actual_parsing_logic do
    IO.puts "🛠️ Testing Actual Parsing Logic"
    IO.puts "=" |> String.duplicate(50)
    
    # Test the actual binary parsing functions with problematic data
    test_data = create_pattern_for_magic_number()
    
    IO.puts "Testing with problematic pattern:"
    IO.puts "Data: #{inspect(test_data, binaries: :as_binaries)}"
    
    try do
      case Bindocsis.parse(test_data, format: :binary) do
        {:ok, tlvs} ->
          IO.puts "✅ Parsing succeeded!"
          IO.puts "TLVs found: #{length(tlvs)}"
          Enum.each(tlvs, fn tlv ->
            IO.puts "  Type: #{tlv.type}, Length: #{tlv.length}"
          end)
          
        {:error, reason} ->
          IO.puts "❌ Parsing failed: #{reason}"
          
          # Try to debug step by step
          debug_step_by_step_parsing(test_data)
      end
    rescue
      error ->
        IO.puts "💥 Exception during parsing: #{Exception.message(error)}"
        IO.puts "Stack trace:"
        IO.puts Exception.format_stacktrace(__STACKTRACE__)
    end
    
    IO.puts "\n"
  end

  defp test_parse_pattern(data) do
    try do
      case Bindocsis.parse(data, format: :binary) do
        {:ok, tlvs} ->
          IO.puts "  ✅ Parsed successfully, found #{length(tlvs)} TLVs"
          
        {:error, reason} ->
          IO.puts "  ❌ Parse error: #{reason}"
          
          # Check if it contains our magic number
          if String.contains?(reason, "134414357") do
            IO.puts "  🎯 MAGIC NUMBER DETECTED! This pattern triggers the bug!"
            debug_this_pattern(data)
          end
      end
    rescue
      error ->
        IO.puts "  💥 Exception: #{Exception.message(error)}"
    end
  end

  defp create_pattern_for_magic_number do
    # Create a byte pattern that might produce 134414357 when misinterpreted
    # The number 134414357 in hex is 0x08050505
    <<0x08, 0x05, 0x05, 0x05>>
  end

  defp debug_this_pattern(data) do
    IO.puts "    🔍 Debugging this specific pattern:"
    IO.puts "    Raw bytes: #{inspect(data, binaries: :as_binaries)}"
    
    # Try to manually parse the first few bytes
    case data do
      <<type, length, rest::binary>> when length < 128 ->
        IO.puts "    Type: #{type}, Single-byte length: #{length}"
        IO.puts "    Remaining data: #{byte_size(rest)} bytes"
        
      <<type, first_length_byte, rest::binary>> when first_length_byte >= 128 ->
        length_bytes = first_length_byte - 128
        IO.puts "    Type: #{type}, Extended length indicator: #{first_length_byte}"
        IO.puts "    Length bytes to follow: #{length_bytes}"
        
        if byte_size(rest) >= length_bytes do
          <<length_data::size(length_bytes)-binary, value_data::binary>> = rest
          decoded_length = :binary.decode_unsigned(length_data, :big)
          IO.puts "    Length data: #{inspect(length_data, binaries: :as_binaries)}"
          IO.puts "    Decoded length: #{decoded_length}"
          IO.puts "    Value data available: #{byte_size(value_data)} bytes"
          
          if decoded_length == 134414357 do
            IO.puts "    🎯 FOUND THE BUG! This is where 134414357 comes from!"
            analyze_length_calculation(first_length_byte, length_data)
          end
        else
          IO.puts "    ❌ Not enough data for extended length"
        end
        
      _ ->
        IO.puts "    Insufficient data for analysis"
    end
  end

  defp debug_step_by_step_parsing(data) do
    IO.puts "  🔍 Step-by-step parsing debug:"
    
    # Manually walk through the parsing logic
    case data do
      <<>> ->
        IO.puts "    Empty data"
        
      <<type>> ->
        IO.puts "    Only type byte: #{type}"
        
      <<type, length_byte, rest::binary>> ->
        IO.puts "    Type: #{type}"
        IO.puts "    Length byte: #{length_byte} (0x#{Integer.to_string(length_byte, 16)})"
        
        if length_byte < 128 do
          IO.puts "    Single-byte length: #{length_byte}"
          IO.puts "    Available data: #{byte_size(rest)} bytes"
          
        else
          length_bytes_count = length_byte - 128
          IO.puts "    Extended length, #{length_bytes_count} bytes to follow"
          
          if byte_size(rest) >= length_bytes_count and length_bytes_count <= 4 do
            <<length_bytes::size(length_bytes_count)-binary, _value::binary>> = rest
            decoded = :binary.decode_unsigned(length_bytes, :big)
            IO.puts "    Length bytes: #{inspect(length_bytes, binaries: :as_binaries)}"
            IO.puts "    Decoded length: #{decoded}"
            
            if decoded == 134414357 do
              IO.puts "    🎯 BUG REPRODUCED!"
              analyze_length_calculation(length_byte, length_bytes)
            end
          else
            IO.puts "    Invalid length bytes count or insufficient data"
          end
        end
    end
  end

  defp analyze_length_calculation(length_indicator, length_bytes) do
    IO.puts "    🧮 Length calculation analysis:"
    IO.puts "    Length indicator: #{length_indicator} (should be 128 + number of length bytes)"
    IO.puts "    Length bytes: #{inspect(length_bytes, binaries: :as_binaries)}"
    
    # Show what the calculation should be vs what it might be doing wrong
    expected_num_bytes = length_indicator - 128
    IO.puts "    Expected number of length bytes: #{expected_num_bytes}"
    
    actual_length = :binary.decode_unsigned(length_bytes, :big)
    IO.puts "    Actual decoded length: #{actual_length}"
    
    # Test different interpretations
    IO.puts "    Alternative interpretations:"
    
    # Maybe it's including the length indicator in the calculation?
    alt1 = (length_indicator <<< (byte_size(length_bytes) * 8)) + actual_length
    IO.puts "    Including indicator: #{alt1}"
    
    # Maybe it's using little-endian instead of big-endian?
    if byte_size(length_bytes) > 1 do
      alt2 = :binary.decode_unsigned(length_bytes, :little)
      IO.puts "    Little-endian: #{alt2}"
    end
    
    # Maybe there's a bit-shifting error?
    for shift <- [0, 8, 16, 24] do
      alt3 = actual_length <<< shift
      IO.puts "    Left-shifted by #{shift}: #{alt3}"
      if alt3 == 134414357 do
        IO.puts "    🎯 POTENTIAL BUG: Wrong bit shift by #{shift}!"
      end
    end
  end
end

# Run the debugger
MTALengthBugDebugger.main()