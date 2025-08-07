#!/usr/bin/env elixir

fixture_path = "test/fixtures/TLV_22_43_10_IPMulticastJoinAuthorization.cm"
binary_data = File.read!(fixture_path)

# Parse with enhancement
{:ok, tlvs} = Bindocsis.parse(binary_data, enhanced: true)

# Generate JSON
{:ok, json_str} = Bindocsis.Generators.JsonGenerator.generate(tlvs, 
  include_names: true, docsis_version: "3.1")

# Write JSON to temp file
temp_json = "/tmp/test_cli.json"
File.write!(temp_json, json_str)

# Try to parse with from_json
IO.puts("Testing from_json:")
case Bindocsis.HumanConfig.from_json(json_str) do
  {:ok, binary} ->
    IO.puts("  Success! Binary size: #{byte_size(binary)}")
    IO.puts("  First 20 bytes: #{Base.encode16(binary_part(binary, 0, min(20, byte_size(binary))))}")
  {:error, reason} ->
    IO.puts("  Error: #{reason}")
end

# Check JSON structure
{:ok, parsed} = JSON.decode(json_str)
IO.puts("\nJSON structure:")
IO.puts("  docsis_version: #{parsed["docsis_version"]}")
IO.puts("  Number of TLVs: #{length(parsed["tlvs"])}")

# Check for any string values that might be problematic
Enum.each(parsed["tlvs"], fn tlv ->
  if is_binary(tlv["formatted_value"]) do
    fv = tlv["formatted_value"]
    if String.length(fv) > 0 do
      first_char = String.first(fv)
      if first_char == "N" do
        IO.puts("\nFound TLV with formatted_value starting with 'N':")
        IO.puts("  Type: #{tlv["type"]}")
        IO.puts("  Name: #{tlv["name"]}")
        IO.puts("  Formatted value: #{inspect(fv)}")
      end
    end
  end
end)