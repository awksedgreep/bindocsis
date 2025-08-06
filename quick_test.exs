#!/usr/bin/env elixir

Code.prepend_path("_build/dev/lib/bindocsis/ebin")

# Test the problematic binary
original = <<3, 1, 1, 18, 1, 0>>
IO.puts("Original: #{inspect(original, base: :hex)}")

try do
  # Step 1: Binary to JSON
  {:ok, json} = Bindocsis.convert(original, from: :binary, to: :json)
  IO.puts("JSON: #{json}")

  # Step 2: JSON to Binary
  {:ok, result} = Bindocsis.convert(json, from: :json, to: :binary)
  IO.puts("Result: #{inspect(result, base: :hex)}")

  # Check difference
  expected = <<3, 1, 1, 18, 1, 0, 255>>
  IO.puts("Expected: #{inspect(expected, base: :hex)}")
  IO.puts("Match: #{result == expected}")

  if result != expected do
    IO.puts("LENGTH DIFFERENCE: result=#{byte_size(result)}, expected=#{byte_size(expected)}")
    IO.puts("Result bytes: #{:binary.bin_to_list(result) |> Enum.join(", ")}")
    IO.puts("Expected bytes: #{:binary.bin_to_list(expected) |> Enum.join(", ")}")
  end
rescue
  e ->
    IO.puts("ERROR: #{Exception.message(e)}")
    IO.puts(Exception.format_stacktrace(__STACKTRACE__))
end
