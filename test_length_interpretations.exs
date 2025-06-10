#!/usr/bin/env elixir

# Simple test to analyze the specific MTA length parsing issue
# Pattern: <<TLV_TYPE, 0x84, 0x08, 0x03, 0x00, 0x15, ...>>

defmodule LengthInterpretationTest do
  def run do
    # The problematic pattern from MTA files
    pattern = <<0x84, 0x08, 0x03, 0x00, 0x15>>
    
    IO.puts("🔍 Analyzing MTA Length Pattern")
    IO.puts("==============================")
    IO.puts("Pattern: #{inspect(pattern)}")
    IO.puts("Hex: #{format_hex(pattern)}")
    IO.puts("")
    
    # Extract the components
    <<length_indicator, b1, b2, b3, b4>> = pattern
    
    IO.puts("Length indicator: 0x#{Integer.to_string(length_indicator, 16)}")
    IO.puts("Length bytes: [#{b1}, #{b2}, #{b3}, #{b4}]")
    IO.puts("")
    
    # Try different interpretations
    interpretations = [
      {"Standard big-endian 32-bit", calculate_big_endian(b1, b2, b3, b4)},
      {"Little-endian 32-bit", calculate_little_endian(b1, b2, b3, b4)},
      {"First 16-bit pair", b1 * 256 + b2},
      {"Second 16-bit pair", b3 * 256 + b4},
      {"Sum of both pairs", (b1 * 256 + b2) + (b3 * 256 + b4)},
      {"Just first byte", b1},
      {"Just second byte", b2},
      {"Just third byte", b3},
      {"Just fourth byte", b4},
      {"Little-endian first pair", b2 * 256 + b1},
      {"Little-endian second pair", b4 * 256 + b3},
      {"BCD interpretation", try_bcd_decode([b1, b2, b3, b4])},
      {"Subtract magic offset", calculate_big_endian(b1, b2, b3, b4) - 134_414_336},  # Try subtracting close to the magic number
    ]
    
    IO.puts("📊 Length Interpretations:")
    IO.puts("-" <> String.duplicate("-", 40))
    
    Enum.each(interpretations, fn {name, length} ->
      status = cond do
        length < 0 -> "❌ Negative"
        length == 0 -> "⚠️  Zero"
        length > 10_000 -> "❌ Too large"
        length > 1000 -> "⚠️  Large"
        length > 0 -> "✅ Reasonable"
        true -> "❓ Unknown"
      end
      
      IO.puts("#{String.pad_trailing(name, 25)} #{String.pad_leading(Integer.to_string(length), 12)} #{status}")
    end)
    
    IO.puts("")
    IO.puts("🎯 Analysis:")
    reasonable = Enum.filter(interpretations, fn {_name, length} -> 
      length > 0 and length <= 1000 
    end)
    
    if Enum.empty?(reasonable) do
      IO.puts("❌ No reasonable interpretations found!")
      IO.puts("   This suggests the pattern might not be a standard length field.")
      IO.puts("   Possible explanations:")
      IO.puts("   1. Different encoding scheme (not TLV)")
      IO.puts("   2. File corruption")
      IO.puts("   3. Different PacketCable standard")
      IO.puts("   4. 0x84 has different meaning in PacketCable")
    else
      IO.puts("✅ Reasonable interpretations found:")
      Enum.each(reasonable, fn {name, length} ->
        IO.puts("   • #{name}: #{length} bytes")
      end)
    end
    
    IO.puts("")
    IO.puts("💡 Hypothesis Test:")
    test_hypothesis()
  end
  
  defp calculate_big_endian(b1, b2, b3, b4) do
    b1 * 0x1000000 + b2 * 0x10000 + b3 * 0x100 + b4
  end
  
  defp calculate_little_endian(b1, b2, b3, b4) do
    b4 * 0x1000000 + b3 * 0x10000 + b2 * 0x100 + b1
  end
  
  defp try_bcd_decode(bytes) do
    # Try to interpret as Binary Coded Decimal
    Enum.reduce(bytes, 0, fn byte, acc ->
      high_nibble = div(byte, 16)
      low_nibble = rem(byte, 16)
      if high_nibble <= 9 and low_nibble <= 9 do
        acc * 100 + high_nibble * 10 + low_nibble
      else
        acc
      end
    end)
  end
  
  defp format_hex(binary) do
    binary
    |> :binary.bin_to_list()
    |> Enum.map(&Integer.to_string(&1, 16))
    |> Enum.map(&String.pad_leading(&1, 2, "0"))
    |> Enum.join(" ")
    |> String.upcase()
  end
  
  defp test_hypothesis do
    IO.puts("Testing hypothesis: Maybe 0x84 doesn't mean 4-byte length in PacketCable")
    IO.puts("")
    
    # What if 0x84 is actually a TLV type, not a length indicator?
    IO.puts("Hypothesis 1: 0x84 is a TLV type, not length indicator")
    IO.puts("   If 0x84 is Type, then next byte (0x08) could be length")
    IO.puts("   That would give us: Type=132, Length=8, Value=[3,0,21,...]")
    IO.puts("   ✅ This seems much more reasonable!")
    IO.puts("")
    
    # What if the whole parsing is off by one byte?  
    IO.puts("Hypothesis 2: Parsing offset issue")
    IO.puts("   Maybe the file has a header byte we're not accounting for")
    IO.puts("   Or the TLV structure starts at a different position")
    IO.puts("")
    
    # What if PacketCable uses a completely different structure?
    IO.puts("Hypothesis 3: PacketCable uses different structure")
    IO.puts("   Maybe not TLV at all, but some other format")
    IO.puts("   Could be fixed-length fields, or different encoding")
    IO.puts("")
    
    IO.puts("🔬 Recommended next steps:")
    IO.puts("1. Try parsing assuming 0x84 is a TLV type (not length)")
    IO.puts("2. Look for PacketCable file format documentation")
    IO.puts("3. Try different starting positions in the binary")
    IO.puts("4. Compare with hex dumps from working PacketCable tools")
  end
end

# Run the test
LengthInterpretationTest.run()