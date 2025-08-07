#!/usr/bin/env elixir

fixture_path = "test/fixtures/TLV41_DsChannelList.cm"
binary_data = File.read!(fixture_path)

# Parse with enhancement
{:ok, tlvs} = Bindocsis.parse(binary_data, enhanced: true)

# Find TLV 41 and subtlv 2
tlv41 = Enum.find(tlvs, &(&1.type == 41))
if tlv41 && tlv41.subtlvs do
  subtlv2 = Enum.find(tlv41.subtlvs, &(&1.type == 2))
  if subtlv2 && subtlv2.subtlvs do
    subtlv3 = Enum.find(subtlv2.subtlvs, &(&1.type == 3))
    if subtlv3 do
      IO.puts("Original Subtlv 2.3:")
      IO.puts("  Type: #{subtlv3.type}")
      IO.puts("  Length: #{subtlv3.length}")
      IO.puts("  Value (hex): #{Base.encode16(subtlv3.value)}")
      IO.puts("  Value (bytes): #{inspect(subtlv3.value, limit: :infinity)}")
      IO.puts("  Value type: #{inspect(subtlv3.value_type)}")
      IO.puts("  Formatted value: #{inspect(subtlv3.formatted_value)}")
    end
  end
end

# Generate JSON and examine it
{:ok, json_str} = Bindocsis.Generators.JsonGenerator.generate(tlvs, 
  include_names: true, docsis_version: "3.1")
  
{:ok, json_data} = JSON.decode(json_str)
tlv41_json = Enum.find(json_data["tlvs"], &(&1["type"] == 41))
if tlv41_json && tlv41_json["subtlvs"] do
  subtlv2_json = Enum.find(tlv41_json["subtlvs"], &(&1["type"] == 2))
  if subtlv2_json && subtlv2_json["subtlvs"] do
    subtlv3_json = Enum.find(subtlv2_json["subtlvs"], &(&1["type"] == 3))
    if subtlv3_json do
      IO.puts("\nJSON Subtlv 2.3:")
      IO.puts("  Type: #{subtlv3_json["type"]}")
      IO.puts("  Length: #{subtlv3_json["length"]}")
      IO.puts("  Formatted value: #{inspect(subtlv3_json["formatted_value"])}")
    end
  end
end

# Parse back and see what happens
{:ok, reparsed_binary} = Bindocsis.HumanConfig.from_json(json_str)
{:ok, final_tlvs} = Bindocsis.parse(reparsed_binary, enhanced: true)

final_tlv41 = Enum.find(final_tlvs, &(&1.type == 41))
if final_tlv41 && final_tlv41.subtlvs do
  final_subtlv2 = Enum.find(final_tlv41.subtlvs, &(&1.type == 2))
  if final_subtlv2 && final_subtlv2.subtlvs do
    final_subtlv3 = Enum.find(final_subtlv2.subtlvs, &(&1.type == 3))
    if final_subtlv3 do
      IO.puts("\nFinal Subtlv 2.3:")
      IO.puts("  Type: #{final_subtlv3.type}")
      IO.puts("  Length: #{final_subtlv3.length}")
      IO.puts("  Value (hex): #{Base.encode16(final_subtlv3.value)}")
      IO.puts("  Value (bytes): #{inspect(final_subtlv3.value, limit: :infinity)}")
      IO.puts("  Value type: #{inspect(final_subtlv3.value_type)}")
      IO.puts("  Formatted value: #{inspect(final_subtlv3.formatted_value)}")
    end
  end
end