#!/usr/bin/env elixir

# Debug the TLV 0 marker issue
filename = "TLV_22_43_5_2_4_2_MPLSPeerIpAddress.cm"
path = "test/fixtures/#{filename}"
binary = File.read!(path)

{:ok, tlvs} = Bindocsis.parse(binary, enhanced: true)

# Find the problematic TLVs - navigate to 22.43.5.2.4.1
main_tlv = Enum.find(tlvs, &(&1.type == 22))
tlv43 = Enum.find(main_tlv.subtlvs, &(&1.type == 43))
tlv5 = Enum.find(tlv43.subtlvs, &(&1.type == 5))
tlv2 = Enum.find(tlv5.subtlvs, &(&1.type == 2))
tlv4 = Enum.find(tlv2.subtlvs, &(&1.type == 4))
tlv1 = Enum.find(tlv4.subtlvs, &(&1.type == 1))

IO.puts("TLV 22.43.5.2.4.1 analysis:")
IO.puts("  Type: #{tlv1.type}")
IO.puts("  Length: #{tlv1.length}")
IO.puts("  Value (hex): #{Base.encode16(tlv1.value)}")
IO.puts("  Value (raw): #{inspect(tlv1.value, base: :hex)}")
IO.puts("  Value type: #{tlv1.value_type}")
IO.puts("  Formatted value: #{inspect(tlv1.formatted_value)}")

# Check the subtlv (should be TLV 0 marker)
if tlv1.subtlvs && length(tlv1.subtlvs) > 0 do
  marker = hd(tlv1.subtlvs)
  IO.puts("  Contains TLV #{marker.type}: length=#{marker.length}")
  IO.puts("    Marker value (hex): #{Base.encode16(marker.value)}")
  IO.puts("    Marker formatted: #{inspect(marker.formatted_value)}")
end

# Also check TLV4 which has the same issue
tlv4_item = Enum.find(tlv4.subtlvs, &(&1.type == 4))
IO.puts("\nTLV 22.43.5.2.4.4 analysis:")
IO.puts("  Type: #{tlv4_item.type}")
IO.puts("  Length: #{tlv4_item.length}")
IO.puts("  Value (hex): #{Base.encode16(tlv4_item.value)}")
IO.puts("  Value (raw): #{inspect(tlv4_item.value, base: :hex)}")
IO.puts("  Value type: #{tlv4_item.value_type}")
IO.puts("  Formatted value: #{inspect(tlv4_item.formatted_value)}")

if tlv4_item.subtlvs && length(tlv4_item.subtlvs) > 0 do
  marker = hd(tlv4_item.subtlvs)
  IO.puts("  Contains TLV #{marker.type}: length=#{marker.length}")
  IO.puts("    Marker value (hex): #{Base.encode16(marker.value)}")
  IO.puts("    Marker formatted: #{inspect(marker.formatted_value)}")
end