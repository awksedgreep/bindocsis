# Test SubTLV 3 enrichment
Mix.install([{:yaml_elixir, "~> 2.11"}], force: true)

# Directly test enrichment path
alias Bindocsis.SubTlvSpecs
alias Bindocsis.TlvEnricher

# Create Sub-TLV 3 (Maximum Upstream Rate) with value 200,000 as uint32
subtlv3_raw = %{type: 3, length: 4, value: <<0, 3, 13, 64>>}

# Get the spec for Sub-TLV 3 in TLV 4
case SubTlvSpecs.get_subtlv_info(4, 3) do
  {:ok, spec} ->
    IO.puts("✅ Sub-TLV 3 spec found:")
    IO.inspect(spec, label: "Spec")
    
  {:error, reason} ->
    IO.puts("❌ Sub-TLV 3 spec not found: #{inspect(reason)}")
end

# Now try enriching TLV 4
tlv4_raw = %{
  type: 4,
  length: 15,
  value: <<1, 1, 1, 2, 4, 0, 15, 66, 64, 3, 4, 0, 3, 13, 64>>
}

enriched = TlvEnricher.enrich_tlv(tlv4_raw, format_values: true, docsis_version: "3.1")

IO.puts("\n✅ Enriched TLV 4:")
IO.inspect(enriched, limit: :infinity, pretty: true)

if Map.has_key?(enriched, :subtlvs) and is_list(enriched.subtlvs) do
  IO.puts("\n🔍 Sub-TLVs found:")
  for subtlv <- enriched.subtlvs do
    IO.puts("\nSub-TLV type #{subtlv.type}:")
    IO.puts("  Name: #{subtlv.name}")
    IO.puts("  Value Type: #{inspect(subtlv.value_type)}")
    IO.puts("  Formatted Value: #{inspect(subtlv.formatted_value)}")
  end
end

