#!/usr/bin/env elixir

binary = File.read!("test/fixtures/BaseConfig.cm")
IO.puts("Testing BaseConfig.cm JSON round-trip...")

case Bindocsis.HumanConfig.to_json(binary) do
  {:ok, json} ->
    IO.puts("✅ JSON generation successful")
    case Bindocsis.HumanConfig.from_json(json) do
      {:ok, _} ->
        IO.puts("✅ JSON round-trip successful")
      {:error, error} ->
        IO.puts("❌ JSON parsing failed: #{error}")
    end
  {:error, error} ->
    IO.puts("❌ JSON generation failed: #{error}")
end