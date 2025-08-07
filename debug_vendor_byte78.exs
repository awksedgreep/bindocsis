#!/usr/bin/env elixir

# Byte 78 is 0x4E which is 'N' in ASCII
IO.puts("Byte 78 (0x4E) is: '#{<<78>>}'")

fixture_path = "test/fixtures/TLV_22_43_10_IPMulticastJoinAuthorization.cm"
binary_data = File.read!(fixture_path)

# Parse with enhancement
{:ok, tlvs} = Bindocsis.parse(binary_data, enhanced: true)

# Generate JSON (vendor test uses JSON)
{:ok, json_str} = Bindocsis.Generators.JsonGenerator.generate(tlvs, 
  include_names: true, docsis_version: "3.1")

# Check if JSON starts with 'N' or has byte 78
first_bytes = String.slice(json_str, 0, 100)
IO.puts("\nFirst 100 chars of JSON: #{inspect(first_bytes)}")

# Also write to file for inspection
File.write!("/tmp/debug_vendor.json", json_str)

# Try to parse it back
case Bindocsis.HumanConfig.from_json(json_str) do
  {:ok, binary} ->
    IO.puts("JSON parsed to binary successfully")
    IO.puts("First 10 bytes: #{Base.encode16(binary_part(binary, 0, min(10, byte_size(binary))))}")
  {:error, reason} ->
    IO.puts("JSON parse error: #{reason}")
end