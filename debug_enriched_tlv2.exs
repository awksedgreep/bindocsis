#!/usr/bin/env elixir

# Debug what JSON we're actually generating

Mix.install([
  {:bindocsis, path: "."}
])

original = <<3, 1, 1, 18, 1, 0>>

IO.puts("Original binary: #{inspect(original, base: :hex)}")

# Let's use the high-level API to see internal structure
{:ok, parsed_struct} = Bindocsis.Read.from_binary(original, format_values: true)

IO.puts("\nParsed structure:")
IO.inspect(parsed_struct, pretty: true, limit: :infinity)

# Check individual TLVs
tlvs = parsed_struct.tlvs || []

tlvs
|> Enum.with_index()
|> Enum.each(fn {tlv, i} ->
  IO.puts("\nTLV #{i}:")

  tlv
  |> Enum.each(fn {key, value} ->
    IO.puts("  #{key}: #{inspect(value)}")
  end)
end)
