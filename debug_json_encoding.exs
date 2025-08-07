#!/usr/bin/env elixir

binary = File.read!("test/fixtures/TLV41_DsChannelList.cm")
{:ok, json} = Bindocsis.HumanConfig.to_json(binary)

# Try to decode it to see where the issue is
case JSON.decode(json) do
  {:ok, _} ->
    IO.puts("✅ JSON is valid")
  {:error, error} ->
    IO.puts("❌ JSON decode error: #{inspect(error)}")
    
    # Save the JSON to inspect
    File.write!("debug_json_output.json", json)
    IO.puts("Saved JSON to debug_json_output.json")
end