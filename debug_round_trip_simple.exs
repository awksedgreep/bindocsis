#!/usr/bin/env elixir

# Debug the failing round-trip test

Mix.install([
  {:bindocsis, path: "."}
])

original = <<3, 1, 1, 18, 1, 0>>

IO.puts("Original binary: #{inspect(original, base: :hex)}")
IO.puts("Original bytes: #{inspect(:binary.bin_to_list(original))}")

{:ok, json} = Bindocsis.convert(original, from: :binary, to: :json)
IO.puts("\nJSON output:")
IO.puts(json)

{:ok, back_to_binary} = Bindocsis.convert(json, from: :json, to: :binary)
IO.puts("\nBack to binary: #{inspect(back_to_binary, base: :hex)}")
IO.puts("Back to binary bytes: #{inspect(:binary.bin_to_list(back_to_binary))}")

expected = <<3, 1, 1, 18, 1, 0, 255>>
IO.puts("\nExpected: #{inspect(expected, base: :hex)}")
IO.puts("Expected bytes: #{inspect(:binary.bin_to_list(expected))}")

IO.puts("\nComparison:")
IO.puts("Are they equal? #{back_to_binary == expected}")
IO.puts("Difference in length: #{byte_size(back_to_binary) - byte_size(expected)}")
