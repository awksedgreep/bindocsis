#!/usr/bin/env elixir

fixture_path = "test/fixtures/TLV41_DsChannelList.cm"
binary_data = File.read!(fixture_path)

# Parse with enhancement
{:ok, tlvs} = Bindocsis.parse(binary_data, enhanced: true)

# Find TLV 41
tlv41 = Enum.find(tlvs, &(&1.type == 41))
if tlv41 && tlv41.subtlvs do
  subtlv2 = Enum.find(tlv41.subtlvs, &(&1.type == 2))
  if subtlv2 do
    IO.puts("Original Subtlv 2:")
    IO.puts("  Length: #{subtlv2.length}")
    IO.puts("  Value (hex): #{Base.encode16(subtlv2.value)}")
    IO.puts("  Subtlvs: #{length(subtlv2.subtlvs || [])}")
    
    if subtlv2.subtlvs do
      Enum.each(subtlv2.subtlvs, fn sub ->
        IO.puts("    Sub-subtlv #{sub.type}: length=#{sub.length}")
      end)
    end
  end
end

# Generate JSON
{:ok, json_str} = Bindocsis.Generators.JsonGenerator.generate(tlvs, 
  include_names: true, docsis_version: "3.1")

# Extract just the subtlv 2 part from JSON
{:ok, json_data} = JSON.decode(json_str)
tlv41_json = Enum.find(json_data["tlvs"], &(&1["type"] == 41))
if tlv41_json && tlv41_json["subtlvs"] do
  subtlv2_json = Enum.find(tlv41_json["subtlvs"], &(&1["type"] == 2))
  if subtlv2_json do
    IO.puts("\nJSON Subtlv 2:")
    IO.puts("  Length: #{subtlv2_json["length"]}")
    IO.puts("  Subtlvs: #{length(subtlv2_json["subtlvs"] || [])}")
    
    if subtlv2_json["subtlvs"] do
      Enum.each(subtlv2_json["subtlvs"], fn sub ->
        IO.puts("    Sub-subtlv #{sub["type"]}: length=#{sub["length"]}")
      end)
    end
  end
end

# Parse back and check
{:ok, reparsed_binary} = Bindocsis.HumanConfig.from_json(json_str)
{:ok, final_tlvs} = Bindocsis.parse(reparsed_binary, enhanced: true)

final_tlv41 = Enum.find(final_tlvs, &(&1.type == 41))
if final_tlv41 && final_tlv41.subtlvs do
  final_subtlv2 = Enum.find(final_tlv41.subtlvs, &(&1.type == 2))
  if final_subtlv2 do
    IO.puts("\nFinal Subtlv 2:")
    IO.puts("  Length: #{final_subtlv2.length}")
    IO.puts("  Value (hex): #{Base.encode16(final_subtlv2.value)}")
    IO.puts("  Subtlvs: #{length(final_subtlv2.subtlvs || [])}")
    
    if final_subtlv2.subtlvs do
      Enum.each(final_subtlv2.subtlvs, fn sub ->
        IO.puts("    Sub-subtlv #{sub.type}: length=#{sub.length}")
      end)
    end
  end
end