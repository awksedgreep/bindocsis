#!/usr/bin/env elixir

# Find exactly which bytes are missing in the L2VPN round-trip
filename = "TLV_22_43_5_2_4_2_MPLSPeerIpAddress.cm"
path = "test/fixtures/#{filename}"
binary = File.read!(path)

{:ok, tlvs} = Bindocsis.parse(binary, enhanced: true)

# Navigate to TLV 22.43.5.2.4 to see what's inside
main_tlv = Enum.find(tlvs, &(&1.type == 22))
tlv43 = Enum.find(main_tlv.subtlvs, &(&1.type == 43))
tlv5 = Enum.find(tlv43.subtlvs, &(&1.type == 5))
tlv2 = Enum.find(tlv5.subtlvs, &(&1.type == 2))
tlv4 = Enum.find(tlv2.subtlvs, &(&1.type == 4))

IO.puts("=== Original TLV 22.43.5.2.4 structure ===")
IO.puts("Length: #{tlv4.length} bytes")
IO.puts("Subtlvs: #{length(tlv4.subtlvs || [])}")

Enum.each(tlv4.subtlvs, fn sub ->
  IO.puts("  Sub-TLV #{sub.type}: length=#{sub.length}")
  if Map.get(sub, :subtlvs) && length(Map.get(sub, :subtlvs, [])) > 0 do
    Enum.each(Map.get(sub, :subtlvs, []), fn subsub ->
      IO.puts("    Sub-sub-TLV #{subsub.type}: length=#{subsub.length}")
    end)
  end
end)

# Calculate expected binary size manually
expected_size = Enum.reduce(tlv4.subtlvs, 0, fn sub, acc ->
  # Each TLV contributes: type(1) + length(1) + value(length)
  tlv_header = 2
  value_size = sub.length
  acc + tlv_header + value_size
end)

IO.puts("\nExpected binary size: #{expected_size} bytes")
IO.puts("Actual original size: #{tlv4.length} bytes")

# Round-trip and check
{:ok, json_str} = Bindocsis.Generators.JsonGenerator.generate(tlvs)
{:ok, reparsed_binary} = Bindocsis.HumanConfig.from_json(json_str)
{:ok, final_tlvs} = Bindocsis.parse(reparsed_binary, enhanced: true)

final_main = Enum.find(final_tlvs, &(&1.type == 22))
final_tlv43 = Enum.find(final_main.subtlvs, &(&1.type == 43))
final_tlv5 = Enum.find(final_tlv43.subtlvs, &(&1.type == 5))
final_tlv2 = Enum.find(final_tlv5.subtlvs, &(&1.type == 2))
final_tlv4 = Enum.find(final_tlv2.subtlvs, &(&1.type == 4))

IO.puts("\n=== Final TLV 22.43.5.2.4 structure ===")
IO.puts("Length: #{final_tlv4.length} bytes")
IO.puts("Subtlvs: #{length(final_tlv4.subtlvs || [])}")

Enum.each(final_tlv4.subtlvs, fn sub ->
  IO.puts("  Sub-TLV #{sub.type}: length=#{sub.length}")
  if Map.get(sub, :subtlvs) && length(Map.get(sub, :subtlvs, [])) > 0 do
    Enum.each(Map.get(sub, :subtlvs, []), fn subsub ->
      IO.puts("    Sub-sub-TLV #{subsub.type}: length=#{subsub.length}")
    end)
  end
end)

# Calculate final expected size
final_expected_size = Enum.reduce(final_tlv4.subtlvs, 0, fn sub, acc ->
  tlv_header = 2
  value_size = sub.length  
  acc + tlv_header + value_size
end)

IO.puts("\nFinal expected binary size: #{final_expected_size} bytes")
IO.puts("Actual final size: #{final_tlv4.length} bytes")
IO.puts("Missing bytes: #{tlv4.length - final_tlv4.length}")