#!/usr/bin/env elixir

# Read the edited JSON file
IO.puts("Reading edited JSON file...")
{:ok, json_content} = File.read("17HarvestMoonCW_editable.json")

# Parse the JSON into TLV structures
IO.puts("Parsing JSON into TLV structures...")
{:ok, tlvs} = Bindocsis.parse(json_content, format: :json)

# Generate the binary DOCSIS file
IO.puts("Generating binary DOCSIS file...")
{:ok, binary} = Bindocsis.generate(tlvs, format: :binary)

# Write the new DOCSIS file
File.write!("17HarvestMoonCW100x75.cm", binary)

IO.puts("✅ Successfully created new DOCSIS file: 17HarvestMoonCW100x75.cm")
IO.puts("📊 File size: #{byte_size(binary)} bytes")
IO.puts("📋 Number of TLVs: #{length(tlvs)}")

# Verify the new file can be parsed
IO.puts("🔍 Verifying new file can be parsed...")
case Bindocsis.parse_file("17HarvestMoonCW100x75.cm") do
  {:ok, verified_tlvs} ->
    IO.puts("✅ Verification successful! Parsed #{length(verified_tlvs)} TLVs")
  {:error, reason} ->
    IO.puts("❌ Verification failed: #{reason}")
end