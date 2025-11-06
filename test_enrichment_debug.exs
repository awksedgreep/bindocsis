# Test SubTLV 3 enrichment with compiled bindocsis
Code.require_file("lib/bindocsis/sub_tlv_specs.ex")

alias Bindocsis.SubTlvSpecs

# Get the spec for Sub-TLV 3 in TLV 4
case SubTlvSpecs.get_subtlv_info(4, 3) do
  {:ok, spec} ->
    IO.puts("✅ Sub-TLV 3 spec found:")
    IO.inspect(spec, label: "Spec")
    IO.puts("\nvalue_type is: #{inspect(spec.value_type)}")
    IO.puts("max_length is: #{inspect(spec.max_length)}")
    
  {:error, reason} ->
    IO.puts("❌ Sub-TLV 3 spec not found: #{inspect(reason)}")
end

