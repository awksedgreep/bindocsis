#!/usr/bin/env elixir

# Debug TLV 24 JSON generation and parsing
Mix.install([{:yamerl, "~> 0.10"}, {:yaml_elixir, "~> 2.9"}])

Code.require_file("lib/bindocsis.ex")

# TLV 24 compound binary from the failing test
compound_binary = <<24, 7, 1, 2, 0, 1, 6, 1, 7>>

IO.puts("=== Original Binary ===")
IO.inspect(compound_binary, limit: :infinity)

IO.puts("\n=== Parse to TLVs ===")
{:ok, tlvs} = Bindocsis.parse(compound_binary, format: :binary)
IO.inspect(tlvs, limit: :infinity)

IO.puts("\n=== Generate JSON ===")
{:ok, json} = Bindocsis.generate(tlvs, format: :json)
IO.puts("JSON: #{json}")

IO.puts("\n=== Parse JSON back ===")
result = Bindocsis.parse(json, format: :json)
IO.puts("Parse result:")
IO.inspect(result, limit: :infinity)
