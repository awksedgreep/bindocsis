#!/usr/bin/env elixir

# Simple test to verify the round-trip issue
Mix.install([{:jason, "~> 1.4"}])
Code.prepend_path("_build/dev/lib/bindocsis/ebin")

# Test the problematic binary
original = <<3, 1, 1, 18, 1, 0>>
IO.puts("Original: #{inspect(original, base: :hex)}")

# Step 1: Binary to JSON
{:ok, json} = Bindocsis.convert(original, from: :binary, to: :json)
IO.puts("JSON generated successfully")

# Step 2: JSON to Binary
{:ok, result} = Bindocsis.convert(json, from: :json, to: :binary)
IO.puts("Result: #{inspect(result, base: :hex)}")

# Check the difference
expected = <<3, 1, 1, 18, 1, 0, 255>>
IO.puts("Expected: #{inspect(expected, base: :hex)}")
IO.puts("Match: #{result == expected}")

if result != expected do
  IO.puts("Bytes differ at:")
  result_list = :binary.bin_to_list(result)
  expected_list = :binary.bin_to_list(expected)

  Enum.with_index(expected_list)
  |> Enum.each(fn {expected_byte, index} ->
    actual_byte = Enum.at(result_list, index, :missing)

    if actual_byte != expected_byte do
      IO.puts("  Position #{index}: expected #{expected_byte}, got #{actual_byte}")
    end
  end)
end
