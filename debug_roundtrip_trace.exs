#!/usr/bin/env elixir

# Debug the exact round-trip conversion to find where bytes are lost
filename = "TLV_22_43_5_2_4_2_MPLSPeerIpAddress.cm"
path = "test/fixtures/#{filename}"
binary = File.read!(path)

IO.puts("=== Round-trip tracing ===")

# Parse original
{:ok, tlvs} = Bindocsis.parse(binary, enhanced: true)
tlv22 = Enum.find(tlvs, &(&1.type == 22))

IO.puts("1. Original TLV 22: length=#{tlv22.length}, subtlvs=#{length(tlv22.subtlvs || [])}")

# Generate JSON 
{:ok, json_str} = Bindocsis.Generators.JsonGenerator.generate(tlvs)

IO.puts("2. JSON generated successfully")

# Parse JSON back to binary
{:ok, reparsed_binary} = Bindocsis.HumanConfig.from_json(json_str)

IO.puts("3. JSON->Binary: #{byte_size(binary)} -> #{byte_size(reparsed_binary)} bytes (#{byte_size(reparsed_binary) - byte_size(binary)} diff)")

# Parse the reparsed binary
{:ok, final_tlvs} = Bindocsis.parse(reparsed_binary, enhanced: true)
final_tlv22 = Enum.find(final_tlvs, &(&1.type == 22))

IO.puts("4. Final TLV 22: length=#{final_tlv22.length}, subtlvs=#{length(final_tlv22.subtlvs || [])}")

# Check TLV 43 specifically
orig_tlv43 = Enum.find(tlv22.subtlvs, &(&1.type == 43))
final_tlv43 = Enum.find(final_tlv22.subtlvs, &(&1.type == 43))

IO.puts("\n=== TLV 43 analysis ===")
IO.puts("Original TLV 43: length=#{orig_tlv43.length}, subtlvs=#{length(orig_tlv43.subtlvs || [])}")
IO.puts("Final TLV 43: length=#{final_tlv43.length}, subtlvs=#{length(final_tlv43.subtlvs || [])}")

# Check the JSON structure for TLV 43
{:ok, json_data} = JSON.decode(json_str)
tlv22_json = Enum.find(json_data["tlvs"], &(&1["type"] == 22))
tlv43_json = Enum.find(tlv22_json["subtlvs"], &(&1["type"] == 43))

IO.puts("\nJSON TLV 43 structure:")
IO.puts("  Has formatted_value: #{Map.has_key?(tlv43_json, "formatted_value")}")
IO.puts("  Has subtlvs: #{Map.has_key?(tlv43_json, "subtlvs")}")
IO.puts("  Subtlvs count: #{length(tlv43_json["subtlvs"] || [])}")

# Test the compound TLV conversion specifically
IO.puts("\n=== Testing convert_compound_tlv_to_binary ===")

# Manual test: create a minimal compound TLV with a TLV 0 marker
test_subtlv = %{
  "type" => 0,
  "value_type" => "marker", 
  "formatted_value" => ""
}

test_compound = %{
  "type" => 1,
  "subtlvs" => [test_subtlv]
}

case Bindocsis.HumanConfig.convert_human_tlv_to_binary(test_compound) do
  {:ok, result} ->
    IO.puts("Test compound TLV: type=#{result.type}, length=#{result.length}")
    IO.puts("Test binary: #{Base.encode16(result.value)}")
    
    # Expected: TLV 0 with length 0 = "00 00" = 2 bytes
    if result.length == 2 && result.value == <<0, 0>> do
      IO.puts("✅ Compound TLV with marker converts correctly")
    else
      IO.puts("❌ Compound TLV conversion issue")
    end
  {:error, reason} ->
    IO.puts("❌ Test failed: #{reason}")
end