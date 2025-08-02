#!/usr/bin/env elixir

# Parse the original DOCSIS file and write it as JSON
{:ok, tlvs} = Bindocsis.parse_file("17HarvestMoonCW.cm")
{:ok, json} = Bindocsis.generate(tlvs, format: :json)

# Write the JSON to disk with pretty formatting
File.write!("17HarvestMoonCW_editable.json", json)

IO.puts("✅ Created editable JSON file: 17HarvestMoonCW_editable.json")
IO.puts("📝 You can now edit this file with any text editor")
IO.puts("")
IO.puts("File size: #{File.stat!("17HarvestMoonCW_editable.json").size} bytes")
IO.puts("Number of TLVs: #{length(tlvs)}")