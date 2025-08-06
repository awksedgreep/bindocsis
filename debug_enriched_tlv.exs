#!/usr/bin/env elixir

# Debug what JSON we're actually generating

Mix.install([
  {:bindocsis, path: "."}
])

original = <<3, 1, 1, 18, 1, 0>>

IO.puts("Original binary: #{inspect(original, base: :hex)}")

# Let's parse this and see the detailed structure
{:ok, parsed_tlvs} = Bindocsis.Parsers.BinaryParser.parse_binary(original)
IO.puts("\nParsed TLVs:")

parsed_tlvs
|> Enum.with_index()
|> Enum.each(fn {tlv, i} ->
  IO.puts("TLV #{i}: #{inspect(tlv)}")
end)

# Let's enrich and see what we get
enriched =
  Enum.map(parsed_tlvs, fn tlv ->
    Bindocsis.TlvEnricher.enrich_tlv(tlv, format_values: true)
  end)

IO.puts("\nEnriched TLVs:")

enriched
|> Enum.with_index()
|> Enum.each(fn {tlv, i} ->
  IO.puts("Enriched TLV #{i}:")

  tlv
  |> Enum.each(fn {key, value} ->
    IO.puts("  #{key}: #{inspect(value)}")
  end)
end)
