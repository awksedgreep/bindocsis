defmodule Bindocsis.RegressionTest do
  use ExUnit.Case
  doctest Bindocsis

  alias Bindocsis
  alias Bindocsis.Generators.JsonGenerator
  alias Bindocsis.Generators.YamlGenerator
  alias Bindocsis.TlvEnricher

  describe "Bug #1: Context-aware TLV naming" do
    test "sub-TLV 6 in service flows shows 'QoS Parameter Set', not 'CM Message Integrity Check'" do
      # Create a downstream service flow with sub-TLV 6
      service_flow_binary = <<
        # Sub-TLV 1: Service Flow Reference (type=1, length=2, value=0x0001)
        1, 2, 0, 1,
        # Sub-TLV 6: QoS Parameter Set (type=6, length=1, value=0x07)
        6, 1, 7,
        # Sub-TLV 7: QoS Parameter Set Type (type=7, length=1, value=0x03)
        7, 1, 3
      >>

      # Parse the service flow TLV
      tlv = %{
        type: 24,
        length: byte_size(service_flow_binary),
        value: service_flow_binary
      }

      # Enrich the TLV
      enriched = TlvEnricher.enrich_tlv(tlv, [])

      # Find sub-TLV 6
      subtlv_6 = Enum.find(enriched.subtlvs, fn sub -> sub.type == 6 end)

      # Bug #1: Sub-TLV 6 should show "QoS Parameter Set", NOT "CM Message Integrity Check"
      assert subtlv_6.name == "QoS Parameter Set",
             "Sub-TLV 6 in service flow should be 'QoS Parameter Set', got: #{subtlv_6.name}"

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

    test "JSON generator uses context-aware naming for sub-TLVs" do
      # Create a service flow with sub-TLV 6
      service_flow = %{
        type: 24,
        name: "Downstream Service Flow",
        value_type: :service_flow,
        subtlvs: [
          %{
            type: 6,
            name: "QoS Parameter Set",
            value: <<7>>,
            length: 1
          }
        ]
      }

      # Convert to JSON using the public API
      {:ok, json} = JsonGenerator.generate([service_flow], [])

      # Verify JSON contains the correct name
      assert String.contains?(json, "QoS Parameter Set"),
             "JSON should contain 'QoS Parameter Set' for sub-TLV 6"

      refute String.contains?(json, "CM Message Integrity Check"),
             "JSON should NOT contain 'CM Message Integrity Check' for sub-TLV 6 in service flow"
    end

    @tag :skip
    test "YAML generator uses context-aware naming for sub-TLVs" do
      # Create a service flow with sub-TLV 6
      service_flow = %{
        type: 24,
        name: "Downstream Service Flow",
        value_type: :service_flow,
        subtlvs: [
          %{
            type: 6,
            name: "QoS Parameter Set",
            value: <<7>>,
            length: 1
          }
        ]
      }

      # Convert to YAML using the public API
      {:ok, yaml} = YamlGenerator.generate([service_flow], [])

      # Verify YAML contains the correct name
      assert String.contains?(yaml, "QoS Parameter Set"),
             "YAML should contain 'QoS Parameter Set' for sub-TLV 6"

      refute String.contains?(yaml, "CM Message Integrity Check"),
             "YAML should NOT contain 'CM Message Integrity Check' for sub-TLV 6 in service flow"
    end
  end

  describe "Bug #2: ASN.1 DER parsing" do
    test "TLV 11 (SNMP MIB Object) with ASN.1 DER data" do
      # Create a real SNMP MIB Object TLV with ASN.1 DER data
      # This contains: sub-TLV 48 with ASN.1 DER encoded OID
      snmp_value = <<
        # Sub-TLV 48: Object Value (ASN.1 DER encoded)
        48, 19,
        # ASN.1 DER: OID tag (0x06), length (0x0B), OID value, then INTEGER tag, length, value
        0x06, 0x0B, 0x2B, 0x06, 0x01, 0x02, 0x01, 0x45, 0x01, 0x02, 0x01, 0x02, 0x01,
        0x40, 0x04, 0xFF, 0xFF, 0xFF, 0xFF
      >>

      tlv = %{
        type: 11,
        length: byte_size(snmp_value),
        value: snmp_value
      }

      # Enrich the TLV
      enriched = TlvEnricher.enrich_tlv(tlv, [])

      # TLV 11 will be parsed as compound because it has sub-TLV specs defined
      # But sub-TLV 48 should have :asn1_der type and NO nested subtlvs
      assert Map.has_key?(enriched, :subtlvs), "TLV 11 should have subtlvs"
      assert length(enriched.subtlvs) == 1, "TLV 11 should have 1 sub-TLV (type 48)"

      subtlv_48 = List.first(enriched.subtlvs)
      assert subtlv_48.type == 48, "Sub-TLV should be type 48"

      # Bug #2: Sub-TLV 48 should have value_type :asn1_der (not :compound)
      assert subtlv_48.value_type == :asn1_der,
             "Sub-TLV 48 should have value_type :asn1_der, got: #{subtlv_48.value_type}"

      # Bug #2: Sub-TLV 48 should NOT have nested subtlvs
      # The ASN.1 bytes (06 0B 2B...) should NOT be parsed as TLV type 6
      refute Map.has_key?(subtlv_48, :subtlvs) && length(subtlv_48.subtlvs) > 0,
             "Sub-TLV 48 should NOT have nested subtlvs (ASN.1 DER should not be parsed as TLVs)"
    end

    test "ASN.1 DER data in sub-TLV 48 is not parsed as TLV structures" do
      # Create TLV 11 with sub-TLV 48 containing ASN.1 DER bytes that LOOK like TLVs
      snmp_value = <<
        # Sub-TLV 48: Object Value
        48, 19,
        # ASN.1 OID: 06 0B looks like Type 6, Length 11 (but it's not!)
        0x06, 0x0B, 0x2B, 0x06, 0x01, 0x02, 0x01, 0x45, 0x01, 0x02, 0x01, 0x02, 0x01,
        # ASN.1 INTEGER: 40 04 looks like Type 64, Length 4 (but it's not!)
        0x40, 0x04, 0xFF, 0xFF, 0xFF, 0xFF
      >>

      tlv_11 = %{
        type: 11,
        length: byte_size(snmp_value),
        value: snmp_value
      }

      # Enrich TLV 11 (which will parse and enrich sub-TLV 48)
      enriched = TlvEnricher.enrich_tlv(tlv_11, [])

      # TLV 11 should have sub-TLV 48
      assert Map.has_key?(enriched, :subtlvs), "TLV 11 should have subtlvs"
      assert length(enriched.subtlvs) == 1, "TLV 11 should have 1 sub-TLV"

      subtlv_48 = List.first(enriched.subtlvs)
      assert subtlv_48.type == 48, "Should be sub-TLV 48"

      # Sub-TLV 48 should NOT have nested subtlvs (ASN.1 bytes should not be parsed)
      refute Map.has_key?(subtlv_48, :subtlvs) && length(subtlv_48.subtlvs) > 0,
             "Sub-TLV 48 should NOT have nested subtlvs (ASN.1 DER should not be parsed as TLVs)"

      # It should have value_type :asn1_der
      assert subtlv_48.value_type == :asn1_der,
             "Sub-TLV 48 should preserve :asn1_der value_type, got: #{subtlv_48.value_type}"
    end
  end

  describe "Full round-trip with both fixes" do
    test "service flow with sub-TLV 6 maintains correct name through enrichment" do
      # Create a service flow binary
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

      # Sub-TLV 6 should have the correct context-aware name
      assert subtlv_6.name == "QoS Parameter Set",
             "Sub-TLV 6 name should be 'QoS Parameter Set' after enrichment"
    end

    test "SNMP MIB Object does not have nested subtlvs after enrichment" do
      # Create SNMP MIB Object with ASN.1 DER data
      snmp_value = <<
        48, 19,
        0x06, 0x0B, 0x2B, 0x06, 0x01, 0x02, 0x01, 0x45, 0x01, 0x02, 0x01, 0x02, 0x01,
        0x40, 0x04, 0xFF, 0xFF, 0xFF, 0xFF
      >>

      tlv = %{
        type: 11,
        length: byte_size(snmp_value),
        value: snmp_value
      }

      # Enrich the TLV
      enriched = TlvEnricher.enrich_tlv(tlv, [])

      # Check TLV 11 has sub-TLV 48
      assert Map.has_key?(enriched, :subtlvs), "TLV 11 should have subtlvs"
      subtlv_48 = List.first(enriched.subtlvs)
      assert subtlv_48.type == 48, "Should have sub-TLV 48"

      # Sub-TLV 48 should NOT have nested subtlvs
      refute Map.has_key?(subtlv_48, :subtlvs) && length(subtlv_48.subtlvs) > 0,
             "Sub-TLV 48 should not have nested subtlvs after enrichment"

      # Sub-TLV 48 should have value_type asn1_der
      assert subtlv_48.value_type == :asn1_der,
             "Sub-TLV 48 should have value_type asn1_der after enrichment"
    end
  end
end
