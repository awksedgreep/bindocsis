#!/usr/bin/env elixir

Mix.install([{:jason, "~> 1.4"}])

# Simple test to see the actual JSON structure for TLV 18
Code.prepend_path("_build/dev/lib/bindocsis/ebin")

# Test the conversion path
# Known working binary
original = <<3, 1, 1, 18, 1, 0>>

# Convert to JSON to see structure
{:ok, json} = Bindocsis.convert(original, from: :binary, to: :json)

# Parse JSON
{:ok, data} = Jason.decode(json)

# Find TLV 18
tlv_18 = Enum.find(data["tlvs"], fn tlv -> tlv["type"] == 18 end)

IO.puts("TLV 18 structure from JSON:")
IO.inspect(tlv_18, pretty: true, limit: :infinity)

# Test what extract_human_value returns for this structure
case Bindocsis.HumanConfig.extract_human_value(tlv_18) do
  {:ok, human_value} ->
    IO.puts("\nHuman value extracted:")
    IO.inspect(human_value, pretty: true, limit: :infinity)

  {:error, reason} ->
    IO.puts("\nError extracting human value: #{reason}")
end
