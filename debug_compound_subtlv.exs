#!/usr/bin/env elixir

# Test compound subtlv conversion specifically  
filename = "TLV_22_43_5_2_4_2_MPLSPeerIpAddress.cm"
path = "test/fixtures/#{filename}"

# Generate JSON and examine the problematic subtlv structure
binary = File.read!(path)
{:ok, tlvs} = Bindocsis.parse(binary, enhanced: true)
{:ok, json_str} = Bindocsis.Generators.JsonGenerator.generate(tlvs)
{:ok, json_data} = JSON.decode(json_str)

# Navigate to TLV 22.43.5.2.4 in JSON
tlv22_json = Enum.find(json_data["tlvs"], &(&1["type"] == 22))
tlv43_json = Enum.find(tlv22_json["subtlvs"], &(&1["type"] == 43))
tlv5_json = Enum.find(tlv43_json["subtlvs"], &(&1["type"] == 5))
tlv2_json = Enum.find(tlv5_json["subtlvs"], &(&1["type"] == 2))
tlv4_json = Enum.find(tlv2_json["subtlvs"], &(&1["type"] == 4))

IO.puts("=== TLV 22.43.5.2.4 JSON structure ===")
IO.puts("Subtlvs: #{length(tlv4_json["subtlvs"])}")

Enum.with_index(tlv4_json["subtlvs"]) |> Enum.each(fn {sub, idx} ->
  IO.puts("\nSub-TLV #{idx + 1} (type #{sub["type"]}):")
  IO.puts("  length: #{sub["length"]}")
  IO.puts("  value_type: #{sub["value_type"]}")
  IO.puts("  formatted_value: #{inspect(sub["formatted_value"])}")
  IO.puts("  has subtlvs: #{Map.has_key?(sub, "subtlvs")}")
  
  if Map.has_key?(sub, "subtlvs") && sub["subtlvs"] do
    IO.puts("  subtlvs count: #{length(sub["subtlvs"])}")
    Enum.each(sub["subtlvs"], fn subsub ->
      IO.puts("    type #{subsub["type"]}: #{inspect(subsub["formatted_value"])} (#{subsub["value_type"]})")
    end)
  end
end)

# Now manually test conversion of the first problematic subtlv (should be type 1)
problem_subtlv = hd(tlv4_json["subtlvs"])
IO.puts("\n=== Manual conversion test ===")
IO.puts("Converting: #{inspect(problem_subtlv, pretty: true)}")

# The problem subtlv should have:
# - type: 1
# - length: 4 (original)  
# - subtlvs: [%{type: 0, length: 0, value_type: "marker", formatted_value: ""}]
# 
# Expected binary: [01][04][00][00][00][01] = 6 bytes
# But we're only getting 2 bytes, suggesting the nested TLV 0 is being lost

# Test the value parser with compound input that has subtlvs
try do
  result = Bindocsis.HumanConfig.from_json(JSON.encode!(%{
    "tlvs" => [problem_subtlv]
  }))
  
  case result do
    {:ok, binary} ->
      IO.puts("Converted to #{byte_size(binary)} bytes: #{Base.encode16(binary)}")
      
      # Parse it back to see structure
      {:ok, parsed} = Bindocsis.parse(binary, enhanced: false)
      tlv = hd(parsed)
      IO.puts("Parsed back: type=#{tlv.type}, length=#{tlv.length}")
      
    {:error, reason} ->
      IO.puts("Conversion error: #{reason}")
  end
rescue
  e -> IO.puts("Exception: #{Exception.message(e)}")
end