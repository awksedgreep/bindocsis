#!/usr/bin/env elixir

# Debug the actual binary structure of the compound TLV
filename = "TLV_22_43_5_2_4_2_MPLSPeerIpAddress.cm"
path = "test/fixtures/#{filename}"
binary = File.read!(path)

{:ok, tlvs} = Bindocsis.parse(binary, enhanced: true)

# Navigate to TLV 22.43.5.2.4.1  
main_tlv = Enum.find(tlvs, &(&1.type == 22))
tlv43 = Enum.find(main_tlv.subtlvs, &(&1.type == 43))
tlv5 = Enum.find(tlv43.subtlvs, &(&1.type == 5))
tlv2 = Enum.find(tlv5.subtlvs, &(&1.type == 2))
tlv4 = Enum.find(tlv2.subtlvs, &(&1.type == 4))
tlv1 = Enum.find(tlv4.subtlvs, &(&1.type == 1))

# Analyze the 4-byte value: 00 00 00 01
value_bytes = tlv1.value
IO.puts("TLV 22.43.5.2.4.1 binary analysis:")
IO.puts("  Raw value: #{Base.encode16(value_bytes, case: :upper)}")
IO.puts("  As bytes: #{inspect(:binary.bin_to_list(value_bytes))}")

# Manual TLV parsing of the 4 bytes
<<type1::8, len1::8, rest::binary>> = value_bytes
IO.puts("  First TLV: type=#{type1}, length=#{len1}")

if len1 == 0 do
  # TLV 0 with length 0, check what's left
  IO.puts("  TLV 0 (marker) with 0 length")
  IO.puts("  Remaining bytes: #{Base.encode16(rest)} (#{inspect(:binary.bin_to_list(rest))})")
  
  if byte_size(rest) >= 2 do
    <<type2::8, len2::8>> = rest
    IO.puts("  Next TLV: type=#{type2}, length=#{len2}")
  end
end

# Check JSON generation to see what happens
{:ok, json_str} = Bindocsis.Generators.JsonGenerator.generate(tlvs)
{:ok, json_data} = JSON.decode(json_str)

# Navigate to find the TLV in JSON
tlv22_json = Enum.find(json_data["tlvs"], &(&1["type"] == 22))
tlv43_json = Enum.find(tlv22_json["subtlvs"], &(&1["type"] == 43))
tlv5_json = Enum.find(tlv43_json["subtlvs"], &(&1["type"] == 5)) 
tlv2_json = Enum.find(tlv5_json["subtlvs"], &(&1["type"] == 2))
tlv4_json = Enum.find(tlv2_json["subtlvs"], &(&1["type"] == 4))
tlv1_json = Enum.find(tlv4_json["subtlvs"], &(&1["type"] == 1))

IO.puts("\n  JSON representation:")
IO.puts("  formatted_value: #{inspect(tlv1_json["formatted_value"])}")
IO.puts("  value_type: #{tlv1_json["value_type"]}")
if tlv1_json["subtlvs"] do
  IO.puts("  subtlvs count: #{length(tlv1_json["subtlvs"])}")
  Enum.each(tlv1_json["subtlvs"], fn sub ->
    IO.puts("    Sub-TLV #{sub["type"]}: formatted_value=#{inspect(sub["formatted_value"])}")
  end)
end