defmodule Bindocsis.Tlv6263Test do
  use ExUnit.Case
  alias Bindocsis.{DocsisSpecs, SubTlvSpecs}

  # Per CL-SP-CANN 11.1: TLV 62 = Upstream Drop Classifier Group ID,
  # TLV 63 = Subscriber Mgmt Control Max CPE IPv6 Prefix. Earlier versions of
  # this library fabricated "OFDM/OFDMA Profile" specs for these types.

  test "TLV 62 is Upstream Drop Classifier Group ID (simple, no sub-TLVs)" do
    {:ok, info} = DocsisSpecs.get_tlv_info(62)
    assert info.name == "Upstream Drop Classifier Group ID"
    assert info.value_type == :binary
    refute info.subtlv_support
    assert {:error, :unknown_tlv} = SubTlvSpecs.get_subtlv_specs(62)
  end

  test "TLV 63 is Subscriber Mgmt Control Max CPE IPv6 Prefix (uint16)" do
    {:ok, info} = DocsisSpecs.get_tlv_info(63)
    assert info.name == "Subscriber Mgmt Control Max CPE IPv6 Prefix"
    assert info.value_type == :uint16
    refute info.subtlv_support
  end

  test "TLV 62 with multiple group IDs round-trips byte-exact" do
    binary = <<62, 6, 1, 2, 3, 4, 5, 6, 255>>
    {:ok, tlvs} = Bindocsis.parse(binary, format: :binary, enhanced: true)
    {:ok, json} = Bindocsis.generate(tlvs, format: :json)
    {:ok, tlvs2} = Bindocsis.parse(json, format: :json)
    {:ok, binary2} = Bindocsis.generate(tlvs2, format: :binary)
    assert binary2 == binary
  end
end
