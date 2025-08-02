#!/usr/bin/env elixir

{:ok, tlvs} = Bindocsis.parse_file("17HarvestMoonCW.cm")
{:ok, pretty_json} = Bindocsis.generate(tlvs, format: :json, pretty: true)
File.write!("17HarvestMoonCW_pretty.json", pretty_json)

IO.puts("✅ Created pretty JSON file: 17HarvestMoonCW_pretty.json")
IO.puts("📊 File size: #{byte_size(pretty_json)} bytes")
IO.puts("")
IO.puts("First 500 characters:")
IO.puts(String.slice(pretty_json, 0, 500))