#!/usr/bin/env elixir

# Compare what we think the original should be vs what the conversion produces
filename = "TLV_22_43_5_2_4_2_MPLSPeerIpAddress.cm"
path = "test/fixtures/#{filename}"
binary = File.read!(path)

{:ok, tlvs} = Bindocsis.parse(binary, enhanced: true)

# Navigate to the first problematic subtlv (TLV 22.43.5.2.4.1)
main_tlv = Enum.find(tlvs, &(&1.type == 22))
tlv43 = Enum.find(main_tlv.subtlvs, &(&1.type == 43))
tlv5 = Enum.find(tlv43.subtlvs, &(&1.type == 5))
tlv2 = Enum.find(tlv5.subtlvs, &(&1.type == 2))
tlv4 = Enum.find(tlv2.subtlvs, &(&1.type == 4))
subtlv1 = Enum.find(tlv4.subtlvs, &(&1.type == 1))

IO.puts("=== Original subtlv 1 analysis ===")
IO.puts("Type: #{subtlv1.type}")
IO.puts("Length: #{subtlv1.length}")
IO.puts("Value (hex): #{Base.encode16(subtlv1.value)}")
IO.puts("Value (bytes): #{inspect(:binary.bin_to_list(subtlv1.value))}")

# Manual decode of the original 4-byte value
<<b1, b2, b3, b4>> = subtlv1.value
IO.puts("Byte breakdown:")
IO.puts("  Byte 1: #{b1} (0x#{Integer.to_string(b1, 16) |> String.pad_leading(2, "0")})")
IO.puts("  Byte 2: #{b2} (0x#{Integer.to_string(b2, 16) |> String.pad_leading(2, "0")})")
IO.puts("  Byte 3: #{b3} (0x#{Integer.to_string(b3, 16) |> String.pad_leading(2, "0")})")
IO.puts("  Byte 4: #{b4} (0x#{Integer.to_string(b4, 16) |> String.pad_leading(2, "0")})")

# What we expect: TLV 0 (marker) = type=0, length=0 = 0000
# But we have 4 bytes: 00000001
# This suggests: TLV 0 with length 0, then TLV 0 with length 1 (but only 0 bytes left)

IO.puts("\nTLV interpretation:")
IO.puts("  TLV 1: type=#{b1}, length=#{b2}")
if b2 == 0 do
  IO.puts("    -> TLV 0 marker (correct)")
  remaining_bytes = [b3, b4]
  IO.puts("  Remaining: #{inspect(remaining_bytes)}")
  if length(remaining_bytes) >= 2 do
    [b3, b4] = remaining_bytes
    IO.puts("  TLV 2: type=#{b3}, length=#{b4}")
    if b4 == 1 && length(remaining_bytes) == 2 do
      IO.puts("    -> TLV 0 with length 1, but no value data (incomplete)")
    end
  end
end

# Check subtlvs that were parsed
IO.puts("\nParsed subtlvs:")
if Map.get(subtlv1, :subtlvs) do
  Enum.each(subtlv1.subtlvs, fn sub ->
    IO.puts("  TLV #{sub.type}: length=#{sub.length}, value=#{Base.encode16(sub.value)}")
  end)
else
  IO.puts("  No subtlvs parsed")
end

IO.puts("\n=== Expected vs Actual conversion ===")

# Test what our converter produces for a TLV 0 marker
expected_output = <<0, 0>>  # Just TLV 0 with length 0
IO.puts("Expected for single TLV 0 marker: #{Base.encode16(expected_output)}")

# But original has 4 bytes, so maybe it should produce more
# If the original 00000001 represents two TLVs:
# - TLV 0, length 0 (2 bytes: 00 00)  
# - TLV 0, length 1 (2 bytes: 00 01, but incomplete - missing 1 byte of data)

# The issue might be that the original binary has malformed/incomplete TLV data
# and during round-trip, we're getting a "corrected" version that only includes complete TLVs

IO.puts("\nHypothesis: Original contains incomplete TLV data that gets corrected during round-trip")
IO.puts("Original 4 bytes (00000001) might represent incomplete TLV structure")
IO.puts("Round-trip produces clean 2 bytes (0000) with only complete TLV 0 marker")