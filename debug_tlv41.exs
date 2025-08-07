#!/usr/bin/env elixir

fixture_path = "test/fixtures/TLV41_DsChannelList.cm"
binary_data = File.read!(fixture_path)

# Parse with enhancement
{:ok, tlvs} = Bindocsis.parse(binary_data, enhanced: true)

IO.puts("Original TLVs count: #{length(tlvs)}")

# Find TLV 41
tlv41 = Enum.find(tlvs, &(&1.type == 41))
if tlv41 do
  IO.puts("\nTLV 41 details:")
  IO.puts("  Name: #{Map.get(tlv41, :name, "N/A")}")
  IO.puts("  Length: #{tlv41.length}")
  IO.puts("  Value type: #{tlv41.value_type}")
  IO.puts("  Subtlvs: #{length(tlv41.subtlvs || [])}")
  
  if tlv41.subtlvs do
    Enum.each(tlv41.subtlvs, fn subtlv ->
      IO.puts("    Subtlv #{subtlv.type}: length=#{subtlv.length}, value_type=#{subtlv.value_type}, formatted_value=#{inspect(String.slice(to_string(subtlv.formatted_value || ""), 0, 30))}")
    end)
  end
end

# Generate JSON and test round-trip
{:ok, json_str} = Bindocsis.Generators.JsonGenerator.generate(tlvs, 
  include_names: true, docsis_version: "3.1")

{:ok, reparsed_binary} = Bindocsis.HumanConfig.from_json(json_str)
{:ok, final_tlvs} = Bindocsis.parse(reparsed_binary, enhanced: true)

IO.puts("\nFinal TLVs count: #{length(final_tlvs)}")

# Check TLV 41 after round-trip
final_tlv41 = Enum.find(final_tlvs, &(&1.type == 41))
if final_tlv41 do
  IO.puts("\nFinal TLV 41 details:")
  IO.puts("  Length: #{final_tlv41.length}")
  IO.puts("  Subtlvs: #{length(final_tlv41.subtlvs || [])}")
  
  if tlv41.length != final_tlv41.length do
    IO.puts("\n⚠️  Length mismatch! Original: #{tlv41.length}, Final: #{final_tlv41.length}")
  end
  
  if final_tlv41.subtlvs do
    IO.puts("\nFinal subtlvs:")
    Enum.each(final_tlv41.subtlvs, fn subtlv ->
      IO.puts("    Subtlv #{subtlv.type}: length=#{subtlv.length}, value_type=#{subtlv.value_type}")
    end)
  end
end