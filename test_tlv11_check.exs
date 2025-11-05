Mix.install([{:bindocsis, path: "."}])

alias Bindocsis.TlvEnricher
alias Bindocsis.DocsisSpecs

# Test TLV 11
{:ok, metadata_11} = DocsisSpecs.get_tlv_info(11, "3.1")
IO.puts("TLV 11 metadata:")
IO.inspect(metadata_11, limit: :infinity)

# Create a test binary value (doesn't matter what it is for this check)
test_value = <<1, 2, 3, 4, 5>>

# Test the check - note: should_attempt_compound_parsing? is private
# So let's test the conditions manually
IO.puts("\nConditions:")
IO.puts("  value_type: #{inspect(metadata_11[:value_type])}")
IO.puts("  subtlv_support: #{inspect(metadata_11[:subtlv_support])}")
IO.puts("  binary length: #{byte_size(test_value)}")

# Check if it's an atomic type
atomic_types = [:uint8, :uint16, :uint32, :int8, :int16, :int32, :boolean, :string, :ipv4, :ipv6, :mac, :oid, :asn1_der, :marker]
has_atomic_type = metadata_11[:value_type] in atomic_types
IO.puts("  has_atomic_type: #{has_atomic_type}")

IO.puts("\nExpected result: false (TLV 11 has subtlv_support: false AND value_type: :asn1_der)")
