defmodule Bindocsis.UnenrichBeforeEncodeTest do
  use ExUnit.Case, async: true

  alias Bindocsis.TlvEnricher
  alias Bindocsis.Generators.BinaryGenerator
  alias Bindocsis.ValueParser

  @downstream_freq_tlv %{
    type: 1,
    length: 4,
    # 591000000 Hz in the existing tests
    value: <<35, 57, 241, 192>>
  }

  test "enriched TLVs are safely unenriched before encoding" do
    tlvs = [@downstream_freq_tlv]

    # Enrich adds formatted_value and other metadata; API returns the enriched TLVs directly
    enriched = TlvEnricher.enrich_tlvs(tlvs, docsis_version: "3.1")

    # Unenrich must remove value-level enrichment so that the core
    # type/length/value fields are suitable for encoding.
    basic_tlvs = TlvEnricher.unenrich_tlvs(enriched)

    assert [%{type: 1, length: 4, value: <<35, 57, 241, 192>>} = basic_tlv] = basic_tlvs

    # Ensure no value-level enrichment keys remain on the TLV used for encoding.
    refute Map.has_key?(basic_tlv, :formatted_value)
    refute Map.has_key?(basic_tlv, :subtlvs)

    # Encoding the unenriched TLVs through the shared BinaryGenerator
    # should produce a stable binary with correct type/length/value.
    binary =
      basic_tlvs
      |> Enum.map(&BinaryGenerator.encode_single_tlv/1)
      |> IO.iodata_to_binary()

    # Type=1, length=4, then the 4-byte frequency value
    assert binary == <<1, 4, 35, 57, 241, 192>>
  end

  test "enrich -> unenrich -> encode round-trips multi-TLV config with TLV 11" do
    # TLV 1: Downstream Frequency
    freq_tlv = @downstream_freq_tlv

    # TLV 11: SNMP MIB Object with sub-TLV 48 containing a simple OCTET STRING value
    snmp_input = %{
      oid: "1.3.6.1.2.1.69.1.2.1.4.1",
      type: "OCTET STRING",
      value: "70726976617465" # "private" in hex
    }

    {:ok, snmp_der} = ValueParser.parse_value(:asn1_der, snmp_input, [])

    snmp_tlv = %{
      type: 11,
      length: byte_size(snmp_der),
      value: snmp_der
    }

    tlvs = [freq_tlv, snmp_tlv]

    # Encode the original TLVs directly as the baseline
    baseline_binary =
      tlvs
      |> Enum.map(&BinaryGenerator.encode_single_tlv/1)
      |> IO.iodata_to_binary()

    # Enrich and then unenrich, then encode again
    enriched = TlvEnricher.enrich_tlvs(tlvs, docsis_version: "3.1")
    basic_tlvs = TlvEnricher.unenrich_tlvs(enriched)

    roundtrip_binary =
      basic_tlvs
      |> Enum.map(&BinaryGenerator.encode_single_tlv/1)
      |> IO.iodata_to_binary()

    assert roundtrip_binary == baseline_binary
  end
end
