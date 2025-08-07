#!/usr/bin/env elixir

# Debug JSON generation for the problematic TLV
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

IO.puts("Before JSON generation:")
IO.puts("  formatted_value: #{inspect(tlv1.formatted_value)}")
IO.puts("  value_type: #{tlv1.value_type}")
IO.puts("  subtlvs: #{length(tlv1.subtlvs || [])}")

# Generate JSON
{:ok, json_str} = Bindocsis.Generators.JsonGenerator.generate(tlvs)
{:ok, json_data} = JSON.decode(json_str)

# Navigate to the same TLV in JSON
tlv22_json = Enum.find(json_data["tlvs"], &(&1["type"] == 22))
tlv43_json = Enum.find(tlv22_json["subtlvs"], &(&1["type"] == 43))
tlv5_json = Enum.find(tlv43_json["subtlvs"], &(&1["type"] == 5))
tlv2_json = Enum.find(tlv5_json["subtlvs"], &(&1["type"] == 2))
tlv4_json = Enum.find(tlv2_json["subtlvs"], &(&1["type"] == 4))
tlv1_json = Enum.find(tlv4_json["subtlvs"], &(&1["type"] == 1))

IO.puts("\nAfter JSON generation:")
IO.puts("  formatted_value: #{inspect(tlv1_json["formatted_value"])}")
IO.puts("  value_type: #{tlv1_json["value_type"]}")
IO.puts("  subtlvs: #{length(tlv1_json["subtlvs"] || [])}")

if tlv1_json["subtlvs"] do
  Enum.each(tlv1_json["subtlvs"], fn sub ->
    IO.puts("    Sub-TLV #{sub["type"]}: #{inspect(sub["formatted_value"])}")
  end)
end

# Now test the round-trip parsing
IO.puts("\nTesting round-trip parsing:")

# Create a minimal JSON structure to test parsing
test_json = %{
  "type" => 1,
  "value_type" => "compound", 
  "formatted_value" => tlv1_json["formatted_value"],
  "subtlvs" => tlv1_json["subtlvs"]
}

IO.puts("Test JSON: #{inspect(test_json)}")

# Try parsing this structure
try do
  case Bindocsis.ValueParser.parse_value(:compound, test_json["formatted_value"], []) do
    {:ok, parsed_binary} ->
      IO.puts("Parsed to binary: #{Base.encode16(parsed_binary)}")
    {:error, reason} ->
      IO.puts("Parse error: #{reason}")
  end
rescue
  e -> IO.puts("Exception: #{Exception.message(e)}")
end