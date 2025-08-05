#!/usr/bin/env elixir

# Test YAML parsing of string TLVs specifically
config = "WebAccessControl enabled\nUpstreamChannelID 5"

IO.puts("Testing YAML parsing issue...")
IO.puts("Original config: #{config}")

# Convert to YAML
{:ok, yaml} = Bindocsis.convert(config, from: :config, to: :yaml)
IO.puts("\nGenerated YAML:")
IO.puts(yaml)

# Try to convert back
case Bindocsis.convert(yaml, from: :yaml, to: :config) do
  {:ok, back_to_config} ->
    IO.puts("\nSuccessfully converted back:")
    IO.puts(back_to_config)
  {:error, error} ->
    IO.puts("\nError converting back: #{error}")
end
