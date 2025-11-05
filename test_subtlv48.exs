Mix.install([{:bindocsis, path: "."}])

alias Bindocsis.TlvEnricher

# Test sub-TLV 48 enrichment with TLV 11 context
asn1_der_bytes = <<
  0x06, 0x0B, 0x2B, 0x06, 0x01, 0x02, 0x01, 0x45, 0x01, 0x02, 0x01, 0x02, 0x01,
  0x40, 0x04, 0xFF, 0xFF, 0xFF, 0xFF
>>

subtlv_48 = %{
  type: 48,
  length: byte_size(asn1_der_bytes),
  value: asn1_der_bytes
}

# Enrich with SNMP MIB Object context (TLV 11)
opts = [context_path: [11]]
enriched = TlvEnricher.enrich_tlv(subtlv_48, opts)

IO.puts("Sub-TLV 48 after enrichment:")
IO.puts("  value_type: #{inspect(enriched.value_type)}")
IO.puts("  has subtlvs: #{Map.has_key?(enriched, :subtlvs)}")
if Map.has_key?(enriched, :subtlvs) do
  IO.puts("  number of subtlvs: #{length(enriched.subtlvs)}")
  Enum.each(enriched.subtlvs, fn sub ->
    IO.puts("    - Type #{sub[:type]}")
  end)
end
