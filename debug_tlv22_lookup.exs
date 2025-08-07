# Debug TLV 22 metadata lookup issue

IO.puts("=== TLV 22 METADATA LOOKUP DEBUG ===")

# Test direct lookup
IO.puts("\n--- Direct DocsisSpecs lookup ---")
case Bindocsis.DocsisSpecs.get_tlv_info(22) do
  {:ok, info} ->
    IO.puts("✓ TLV 22 found:")
    IO.puts("  Name: #{info.name}")
    IO.puts("  Value Type: #{inspect(info.value_type)}")
    IO.puts("  SubTLV Support: #{inspect(info.subtlv_support)}")
  {:error, reason} ->
    IO.puts("❌ TLV 22 lookup failed: #{reason}")
end

# Test the enricher's get_tlv_metadata function
IO.puts("\n--- Enricher metadata lookup ---")
# We can't call the private function directly, but we can test enrichment
test_tlv = %{type: 22, length: 20, value: <<43, 11, 8, 3, 255, 255, 255, 1, 4, 0, 0, 0, 1, 1, 1, 1, 3, 2, 0, 1>>}

enriched = Bindocsis.TlvEnricher.enrich_tlv(test_tlv, [])
IO.puts("Enriched TLV 22:")
IO.puts("  Name: #{inspect(enriched.name)}")
IO.puts("  Value Type: #{inspect(enriched.value_type)}")
IO.puts("  SubTLV Support: #{inspect(Map.get(enriched, :subtlv_support))}")

# Check if we have subtlvs
if Map.has_key?(enriched, :subtlvs) do
  IO.puts("  Subtlvs: #{length(enriched.subtlvs)} found")
else
  IO.puts("  Subtlvs: none")
end

# Test get_spec function too
IO.puts("\n--- get_spec(3.1) for TLV 22 ---")
spec = Bindocsis.DocsisSpecs.get_spec("3.1")
tlv_22_spec = Map.get(spec, 22)
if tlv_22_spec do
  IO.puts("✓ TLV 22 in spec:")
  IO.puts("  Name: #{tlv_22_spec.name}")
  IO.puts("  Value Type: #{inspect(tlv_22_spec.value_type)}")
  IO.puts("  SubTLV Support: #{inspect(tlv_22_spec.subtlv_support)}")
else
  IO.puts("❌ TLV 22 not found in get_spec(\"3.1\")")
end

# Let's also check what happens with service flow subtlvs
IO.puts("\n--- Service Flow SubTLV lookup for reference ---")
case Bindocsis.DocsisSpecs.get_service_flow_subtlvs(25) do
  {:ok, subtlvs} ->
    if Map.has_key?(subtlvs, 22) do
      IO.puts("⚠️  TLV 22 found in Upstream Service Flow subtlvs:")
      subtlv_22 = subtlvs[22]
      IO.puts("  Name: #{subtlv_22.name}")
      IO.puts("  Value Type: #{inspect(subtlv_22.value_type)}")
      IO.puts("This should NOT interfere with top-level TLV 22 lookup!")
    else
      IO.puts("✓ TLV 22 not in Upstream Service Flow subtlvs")
    end
  {:error, reason} ->
    IO.puts("Service flow subtlv lookup failed: #{reason}")
end