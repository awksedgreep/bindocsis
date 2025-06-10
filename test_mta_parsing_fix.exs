#!/usr/bin/env elixir

# Test to demonstrate the MTA parsing fix for 0x84 TLV type issue
# This reproduces the exact problem described in mta_status.md and shows the fix

Mix.install([
  {:bindocsis, path: "."}
])

defmodule MTAParsingFixTest do
  @moduledoc """
  Test to demonstrate the fix for MTA binary parsing issue where TLV type 0x84 
  (Line Package) was being misinterpreted as an extended length indicator.
  
  The problematic pattern was:
  <<TLV_TYPE, 0x84, 0x08, 0x03, 0x00, 0x15, ...>>
  
  Where 0x84 was incorrectly parsed as "4-byte extended length indicator"
  causing massive length values (134,414,357 bytes) instead of recognizing
  it as PacketCable TLV type 84 "Line Package".
  """

  def run do
    IO.puts("🧪 MTA Binary Parsing Fix Test")
    IO.puts("=" <> String.duplicate("=", 40))
    IO.puts("")
    
    # Create the problematic binary pattern from the status document
    test_binary = create_problematic_mta_binary()
    
    IO.puts("📁 Test Binary Created:")
    IO.puts("   Size: #{byte_size(test_binary)} bytes")
    IO.puts("   Hex:  #{format_hex(test_binary)}")
    IO.puts("")
    
    # Show what the old parser would do (simulate the error)
    test_old_parsing_behavior(test_binary)
    
    # Show what the new parser does
    test_new_parsing_behavior(test_binary)
    
    # Additional test cases
    test_additional_scenarios()
  end
  
  def create_problematic_mta_binary do
    # Create binary that reproduces the exact issue from mta_status.md
    # Pattern: <<TLV_TYPE, 0x84, 0x08, 0x03, 0x00, 0x15, ...>>
    
    <<
      # First TLV - some basic DOCSIS parameter
      0x01, 0x04, 0x12, 0x34, 0x56, 0x78,  # Type=1, Length=4, Value=[0x12,0x34,0x56,0x78]
      
      # The problematic sequence:
      0x43,  # Some TLV type (67 - Media Gateway)
      0x84,  # This was being interpreted as extended length, but it's actually TLV type 84 (Line Package)
      0x08,  # Length of Line Package TLV = 8 bytes
      0x03, 0x00, 0x15, 0x01, 0x02, 0x03, 0x04, 0x05,  # 8 bytes of Line Package data
      
      # Another TLV to show parsing continues
      0x45, 0x02, 0xAB, 0xCD  # Type=69 (Kerberos Realm), Length=2, Value=[0xAB, 0xCD]
    >>
  end
  
  def test_old_parsing_behavior(binary) do
    IO.puts("❌ Old Parsing Behavior (simulated):")
    IO.puts("   Problem: 0x84 interpreted as extended length indicator")
    IO.puts("   Length bytes [0x08, 0x03, 0x00, 0x15] = #{calculate_big_endian(0x08, 0x03, 0x00, 0x15)} bytes")
    IO.puts("   Error: 'need 134414357 bytes but only have #{byte_size(binary)}'")
    IO.puts("   Status: ❌ PARSING FAILED")
    IO.puts("")
  end
  
  def test_new_parsing_behavior(binary) do
    IO.puts("✅ New Parsing Behavior:")
    IO.puts("   Recognition: 0x84 is PacketCable TLV type 84 'Line Package'")
    
    # Try to parse with the new MTA parser
    case Bindocsis.Parsers.MtaBinaryParser.parse(binary) do
      {:ok, tlvs} ->
        IO.puts("   Status: ✅ PARSING SUCCEEDED")
        IO.puts("   TLVs parsed: #{length(tlvs)}")
        IO.puts("")
        
        IO.puts("   📋 Parsed TLVs:")
        Enum.with_index(tlvs, 1) |> Enum.each(fn {tlv, index} ->
          name = tlv[:name] || "Unknown TLV Type #{tlv.type}"
          IO.puts("   #{index}. Type #{tlv.type} (#{name})")
          IO.puts("      Length: #{tlv.length} bytes") 
          IO.puts("      Value: #{format_hex(tlv.value)}")
          if tlv[:mta_specific] do
            IO.puts("      🎯 MTA-specific TLV")
          end
          IO.puts("")
        end)
        
      {:error, reason} ->
        IO.puts("   Status: ❌ PARSING STILL FAILED")
        IO.puts("   Error: #{reason}")
        IO.puts("")
        
        # Try debug parsing
        debug_result = Bindocsis.Parsers.MtaBinaryParser.debug_parse(binary)
        IO.puts("   🔍 Debug Information:")
        IO.puts("   #{inspect(debug_result, pretty: true)}")
    end
  end
  
  def test_additional_scenarios do
    IO.puts("🧪 Additional Test Scenarios:")
    IO.puts("-" <> String.duplicate("-", 30))
    
    # Test 1: Multiple 0x8X TLV types in sequence
    test_multiple_8x_types()
    
    # Test 2: Real extended length encoding mixed with 0x8X TLV types  
    test_mixed_length_encodings()
    
    # Test 3: Edge cases
    test_edge_cases()
  end
  
  def test_multiple_8x_types do
    IO.puts("Test 1: Multiple 0x8X TLV types in sequence")
    
    # Create binary with multiple TLV types in 0x80-0x8F range
    binary = <<
      0x84, 0x04, 0x01, 0x02, 0x03, 0x04,  # Line Package (84)
      0x85, 0x08, "MTACert\0",              # MTA Certificate (85) 
      0x81, 0x02, 0xFF, 0xEE                # Emergency Services (81)
    >>
    
    case Bindocsis.Parsers.MtaBinaryParser.parse(binary) do
      {:ok, tlvs} ->
        IO.puts("   ✅ Success: Parsed #{length(tlvs)} TLVs")
        Enum.each(tlvs, fn tlv ->
          name = tlv[:name] || "Unknown"
          IO.puts("      Type #{tlv.type} (#{name}): #{tlv.length} bytes")
        end)
      {:error, reason} ->
        IO.puts("   ❌ Failed: #{reason}")
    end
    IO.puts("")
  end
  
  def test_mixed_length_encodings do
    IO.puts("Test 2: Mixed length encodings")
    
    # Test legitimate extended length encoding alongside TLV types
    large_value = String.duplicate("X", 200)  # 200 bytes
    
    binary = <<
      0x64, 0x81, byte_size(large_value), large_value::binary,  # Extended length encoding
      0x84, 0x04, 0x01, 0x02, 0x03, 0x04                       # TLV type 84
    >>
    
    case Bindocsis.Parsers.MtaBinaryParser.parse(binary) do
      {:ok, tlvs} ->
        IO.puts("   ✅ Success: Parsed #{length(tlvs)} TLVs")
        Enum.each(tlvs, fn tlv ->
          name = tlv[:name] || "Unknown"
          value_preview = if tlv.length > 10 do
            "#{format_hex(binary_part(tlv.value, 0, 10))}..."
          else
            format_hex(tlv.value)
          end
          IO.puts("      Type #{tlv.type} (#{name}): #{tlv.length} bytes, Value: #{value_preview}")
        end)
      {:error, reason} ->
        IO.puts("   ❌ Failed: #{reason}")
    end
    IO.puts("")
  end
  
  def test_edge_cases do
    IO.puts("Test 3: Edge cases")
    
    # Test case: 0x84 followed by data that could be length or value
    edge_binary = <<0x84, 0x84, 0x02, 0xAA, 0xBB>>  # Type 84, potential confusion
    
    case Bindocsis.Parsers.MtaBinaryParser.parse(edge_binary) do
      {:ok, tlvs} ->
        IO.puts("   ✅ Edge case handled: #{length(tlvs)} TLVs")
        Enum.each(tlvs, fn tlv ->
          name = tlv[:name] || "Unknown"
          IO.puts("      Type #{tlv.type} (#{name}): #{tlv.length} bytes")
        end)
      {:error, reason} ->
        IO.puts("   ❌ Edge case failed: #{reason}")
    end
    IO.puts("")
  end
  
  # Helper functions
  defp calculate_big_endian(b1, b2, b3, b4) do
    b1 * 0x1000000 + b2 * 0x10000 + b3 * 0x100 + b4
  end
  
  defp format_hex(binary) when is_binary(binary) do
    binary
    |> :binary.bin_to_list()
    |> Enum.map(&Integer.to_string(&1, 16))
    |> Enum.map(&String.pad_leading(&1, 2, "0"))
    |> Enum.join(" ")
    |> String.upcase()
  end
end

# Run the test
MTAParsingFixTest.run()