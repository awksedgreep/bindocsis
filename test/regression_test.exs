defmodule Bindocsis.RegressionTest do
  use ExUnit.Case
  doctest Bindocsis

  alias Bindocsis
  alias Bindocsis.Generators.JsonGenerator
  alias Bindocsis.Generators.YamlGenerator
  alias Bindocsis.TlvEnricher

  describe "Bug #1: Context-aware TLV naming" do
    # Per CANN-I22: TLV 24 = Upstream Service Flow (not Downstream!)
    # Sub-TLV 6 = QoS Parameter Set Type (not "QoS Parameter Set")
    # Sub-TLV 7 = Traffic Priority (not "QoS Parameter Set Type")
    test "sub-TLV 6 in service flows shows 'QoS Parameter Set Type', not 'CM Message Integrity Check'" do
      # Create an upstream service flow with sub-TLV 6
      service_flow_binary = <<
        # Sub-TLV 1: Service Flow Reference (type=1, length=2, value=0x0001)
        1,
        2,
        0,
        1,
        # Sub-TLV 6: QoS Parameter Set Type (type=6, length=1, value=0x07)
        6,
        1,
        7,
        # Sub-TLV 7: Traffic Priority (type=7, length=1, value=0x03)
        7,
        1,
        3
      >>

      # Parse the service flow TLV (24 = Upstream Service Flow per CANN-I22)
      tlv = %{
        type: 24,
        length: byte_size(service_flow_binary),
        value: service_flow_binary
      }

      # Enrich the TLV
      enriched = TlvEnricher.enrich_tlv(tlv, [])

      # Find sub-TLV 6
      subtlv_6 = Enum.find(enriched.subtlvs, fn sub -> sub.type == 6 end)

      # Per CANN-I22: Sub-TLV 6 should show "QoS Parameter Set Type", NOT "CM Message Integrity Check"
      assert subtlv_6.name == "QoS Parameter Set Type",
             "Sub-TLV 6 in service flow should be 'QoS Parameter Set Type', got: #{subtlv_6.name}"

      refute subtlv_6.name == "CM Message Integrity Check",
             "Sub-TLV 6 should NOT be 'CM Message Integrity Check' in service flow context"
    end

    test "global TLV 6 shows 'CM Message Integrity Check'" do
      # Create a top-level TLV 6 (CM MIC)
      mic_value = <<1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16>>

      tlv = %{
        type: 6,
        length: byte_size(mic_value),
        value: mic_value
      }

      # Enrich the TLV
      enriched = TlvEnricher.enrich_tlv(tlv, [])

      # Global TLV 6 should show "CM Message Integrity Check"
      assert enriched.name == "CM Message Integrity Check",
             "Global TLV 6 should be 'CM Message Integrity Check', got: #{enriched.name}"
    end

    # Per CANN-I22: TLV 24 = Upstream Service Flow, Sub-TLV 6 = QoS Parameter Set Type
    test "JSON generator uses context-aware naming for sub-TLVs" do
      # Create an upstream service flow with sub-TLV 6
      service_flow = %{
        type: 24,
        name: "Upstream Service Flow",
        value_type: :service_flow,
        subtlvs: [
          %{
            type: 6,
            name: "QoS Parameter Set Type",
            value: <<7>>,
            length: 1
          }
        ]
      }

      # Convert to JSON using the public API
      {:ok, json} = JsonGenerator.generate([service_flow], [])

      # Verify JSON contains the correct name per CANN-I22
      assert String.contains?(json, "QoS Parameter Set Type"),
             "JSON should contain 'QoS Parameter Set Type' for sub-TLV 6"

      refute String.contains?(json, "CM Message Integrity Check"),
             "JSON should NOT contain 'CM Message Integrity Check' for sub-TLV 6 in service flow"
    end

    @tag :skip
    # Per CANN-I22: TLV 24 = Upstream Service Flow, Sub-TLV 6 = QoS Parameter Set Type
    test "YAML generator uses context-aware naming for sub-TLVs" do
      # Create an upstream service flow with sub-TLV 6
      service_flow = %{
        type: 24,
        name: "Upstream Service Flow",
        value_type: :service_flow,
        subtlvs: [
          %{
            type: 6,
            name: "QoS Parameter Set Type",
            value: <<7>>,
            length: 1
          }
        ]
      }

      # Convert to YAML using the public API
      {:ok, yaml} = YamlGenerator.generate([service_flow], [])

      # Verify YAML contains the correct name per CANN-I22
      assert String.contains?(yaml, "QoS Parameter Set Type"),
             "YAML should contain 'QoS Parameter Set Type' for sub-TLV 6"

      refute String.contains?(yaml, "CM Message Integrity Check"),
             "YAML should NOT contain 'CM Message Integrity Check' for sub-TLV 6 in service flow"
    end
  end

  describe "Bug #2: ASN.1 DER parsing" do
    # Per MULPI C.1.1.11, TLV 11's value is a single ASN.1 BER VarBind
    # (SEQUENCE of OID + value). It is a LEAF: the 0x30 SEQUENCE tag must not
    # be misparsed as a "sub-TLV 48".
    test "TLV 11 (SNMP MIB Object) enriches as a leaf VarBind" do
      snmp_value = <<
        48,
        19,
        0x06,
        0x0B,
        0x2B,
        0x06,
        0x01,
        0x02,
        0x01,
        0x45,
        0x01,
        0x02,
        0x01,
        0x02,
        0x01,
        0x40,
        0x04,
        0xFF,
        0xFF,
        0xFF,
        0xFF
      >>

      tlv = %{
        type: 11,
        length: byte_size(snmp_value),
        value: snmp_value
      }

      enriched = TlvEnricher.enrich_tlv(tlv, [])

      # :hex_string is the lossless fallback when the VarBind uses tags the
      # pretty-printer does not decode (e.g. SNMP application tag 0x40)
      assert enriched.value_type in [:asn1_der, :hex_string]

      refute Map.has_key?(enriched, :subtlvs) && length(enriched.subtlvs) > 0,
             "TLV 11 must not be parsed into sub-TLVs (its value is one ASN.1 VarBind)"

      assert enriched.formatted_value != nil
    end

    test "TLV 11 round-trips byte-exact through JSON" do
      snmp_value = <<
        48,
        19,
        0x06,
        0x0B,
        0x2B,
        0x06,
        0x01,
        0x02,
        0x01,
        0x45,
        0x01,
        0x02,
        0x01,
        0x02,
        0x01,
        0x40,
        0x04,
        0xFF,
        0xFF,
        0xFF,
        0xFF
      >>

      binary = <<11, byte_size(snmp_value)::8, snmp_value::binary, 0xFF>>

      {:ok, tlvs} = Bindocsis.parse(binary, format: :binary, enhanced: true)
      {:ok, json} = Bindocsis.generate(tlvs, format: :json)
      {:ok, tlvs2} = Bindocsis.parse(json, format: :json)
      {:ok, binary2} = Bindocsis.generate(tlvs2, format: :binary)

      assert binary2 == binary
    end
  end

  describe "Full round-trip with both fixes" do
    # Per CANN-I22: Sub-TLV 6 = QoS Parameter Set Type
    test "service flow with sub-TLV 6 maintains correct name through enrichment" do
      # Create an upstream service flow binary (TLV 24 per CANN-I22)
      service_flow_binary = <<1, 2, 0, 1, 6, 1, 7>>

      tlv = %{
        type: 24,
        length: byte_size(service_flow_binary),
        value: service_flow_binary
      }

      # Enrich the TLV
      enriched = TlvEnricher.enrich_tlv(tlv, [])

      # Find sub-TLV 6
      subtlv_6 = Enum.find(enriched.subtlvs, fn s -> s.type == 6 end)

      # Per CANN-I22: Sub-TLV 6 should have name "QoS Parameter Set Type"
      assert subtlv_6.name == "QoS Parameter Set Type",
             "Sub-TLV 6 name should be 'QoS Parameter Set' after enrichment"
    end

    test "SNMP MIB Object does not have nested subtlvs after enrichment" do
      snmp_value = <<
        48,
        19,
        0x06,
        0x0B,
        0x2B,
        0x06,
        0x01,
        0x02,
        0x01,
        0x45,
        0x01,
        0x02,
        0x01,
        0x02,
        0x01,
        0x40,
        0x04,
        0xFF,
        0xFF,
        0xFF,
        0xFF
      >>

      tlv = %{
        type: 11,
        length: byte_size(snmp_value),
        value: snmp_value
      }

      enriched = TlvEnricher.enrich_tlv(tlv, [])

      refute Map.has_key?(enriched, :subtlvs) && length(enriched.subtlvs) > 0,
             "TLV 11 must not have nested subtlvs (leaf ASN.1 VarBind)"

      assert enriched.value_type in [:asn1_der, :hex_string]
    end
  end
end
