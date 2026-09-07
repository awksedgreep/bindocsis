defmodule Bindocsis.SubTlvSpecsTest do
  use ExUnit.Case
  alias Bindocsis.SubTlvSpecs

  @moduledoc """
  Tests for sub-TLV specifications.

  Every asserted table is backed by a spec citation (CM-SP-MULPIv3.1 Annex C,
  CL-SP-CANN section 11, CM-SP-eRouter Annex B.4, DEMARCv1.0 Annex B). TLVs
  without a verifiable spec table intentionally return {:error, :unknown_tlv}
  so their children get honest generic naming.
  """

  describe "extended compound TLV sub-TLVs (64-79)" do
    test "TLV 64 (CMTS Static Multicast Session) per MULPI C.1.1.27" do
      assert {:ok, subtlvs} = SubTlvSpecs.get_subtlv_specs(64)
      assert subtlvs[1].name == "Static Multicast Group Encoding"
      assert subtlvs[2].name == "Static Multicast Source Encoding"
      assert subtlvs[3].name == "Static Multicast CMIM Encoding"
      # Group/source addresses may be IPv4 or IPv6 - stored as binary
      assert subtlvs[1].value_type == :binary
    end

    test "TLV 65 (L2VPN MAC Aging) per CANN 11.1.2.3" do
      assert {:ok, subtlvs} = SubTlvSpecs.get_subtlv_specs(65)
      assert subtlvs[1].name == "L2VPN MAC Aging Mode"
    end

    test "TLV 67 (Subscriber Mgmt CPE IPv6) has IPv6 sub-TLVs" do
      assert {:ok, subtlvs} = SubTlvSpecs.get_subtlv_specs(67)
      assert subtlvs[1].value_type == :ipv6
    end

    test "TLV 69 (MAC Address Learning Control) per MULPI C.1.2.18" do
      assert {:ok, subtlvs} = SubTlvSpecs.get_subtlv_specs(69)
      assert subtlvs[1].name == "MAC Address Learning Control"
      assert subtlvs[2].name == "MAC Address Learning Holdoff Timer"
      assert subtlvs[2].value_type == :uint8
    end

    test "TLV 70/71 (Aggregate Service Flow) share the service flow numbering" do
      assert {:ok, subtlvs} = SubTlvSpecs.get_subtlv_specs(70)
      assert {:ok, ^subtlvs} = SubTlvSpecs.get_subtlv_specs(71)
    end

    test "TLV 72 (Metro Ethernet Service Profile) per CANN 11.1.7" do
      assert {:ok, subtlvs} = SubTlvSpecs.get_subtlv_specs(72)
      assert subtlvs[1].name == "MESP Reference"
      assert subtlvs[1].value_type == :uint8
      assert subtlvs[2].name == "MESP Bandwidth Profile"
      assert subtlvs[2].value_type == :compound
      assert subtlvs[3].name == "MESP Name"
      assert subtlvs[3].value_type == :string_null

      assert {:ok, bp} = SubTlvSpecs.get_subtlv_specs([72, 2])
      assert bp[1].name == "MESP-BP Committed Information Rate"
      assert bp[6].value_type == :compound
    end

    test "TLV 73 (Network Timing Profile) per MULPI C.1.2.19" do
      assert {:ok, subtlvs} = SubTlvSpecs.get_subtlv_specs(73)
      assert subtlvs[1].name == "Network Timing Profile Reference"
      assert subtlvs[1].value_type == :uint16
      assert subtlvs[2].name == "Network Timing Profile Name"
      assert subtlvs[2].value_type == :string_null
    end

    test "TLV 74 (Energy Management) per MULPI C.1.1.30" do
      assert {:ok, subtlvs} = SubTlvSpecs.get_subtlv_specs(74)
      assert subtlvs[1].name == "Energy Management Feature Control"
      assert subtlvs[2].name == "Energy Management 1x1 Mode Encodings"
      assert subtlvs[3].name == "Energy Management Cycle Period"
      assert subtlvs[4].name == "Energy Management DOCSIS Light Sleep Mode Encodings"

      # 74.2 and 74.4 share the activity-detection structure (C.1.1.30.4)
      for mode <- [2, 4] do
        assert {:ok, wrapper} = SubTlvSpecs.get_subtlv_specs([74, mode])
        assert wrapper[1].name == "Downstream Activity Detection Parameters"
        assert wrapper[2].name == "Upstream Activity Detection Parameters"

        assert {:ok, ds} = SubTlvSpecs.get_subtlv_specs([74, mode, 1])
        assert ds[1].name == "Downstream Entry Bitrate Threshold"
        assert ds[1].value_type == :uint32
        assert ds[2].value_type == :uint16
      end
    end

    test "TLV 79 (UNI Control) per MULPI C.3.3" do
      assert {:ok, subtlvs} = SubTlvSpecs.get_subtlv_specs(79)
      assert subtlvs[1].name == "Context CMIM"
      assert subtlvs[2].name == "UNI Admin Status"
      assert subtlvs[4].name == "UNI Operating Speed"
      assert subtlvs[7].name == "Maximum Frame Size"
      assert subtlvs[7].value_type == :uint16
    end
  end

  describe "TLVs without verifiable sub-TLV specs return :unknown_tlv" do
    test "simple TLVs have no sub-TLV tables" do
      # 62 = UDC Group ID (byte list), 63 = Max CPE IPv6 (uint16),
      # 66 = Management Event Control (uint32 event ID), 68 = buffer ms (uint16)
      for type <- [62, 63, 66, 68] do
        assert {:error, :unknown_tlv} = SubTlvSpecs.get_subtlv_specs(type),
               "TLV #{type} is a simple value per spec and must not have sub-TLV specs"
      end
    end

    test "unverified extended TLVs are honest unknowns, not fabrications" do
      # DOCSIS 3.1/4.0 TLVs whose sub-structure has not been transcribed from
      # spec yet: better generic naming than invented tables.
      for type <- [80, 88, 93, 94, 150] do
        assert {:error, :unknown_tlv} = SubTlvSpecs.get_subtlv_specs(type)
      end
    end
  end

  describe "classifier sub-TLVs (22/23/60) per CANN 11.1.4" do
    test "all three classifier TLVs share the numbering plan" do
      assert {:ok, t22} = SubTlvSpecs.get_subtlv_specs(22)
      assert {:ok, ^t22} = SubTlvSpecs.get_subtlv_specs(23)
      assert {:ok, ^t22} = SubTlvSpecs.get_subtlv_specs(60)
    end

    test "classifier field encodings are named per MULPI C.2.1" do
      {:ok, t} = SubTlvSpecs.get_subtlv_specs(22)
      assert t[9].name == "IPv4 Packet Classification Encodings"
      assert t[11].name == "IEEE 802.1P/Q Packet Classification Encodings"
      assert t[12].name == "IPv6 Packet Classification Encodings"
      assert t[16].name == "ICMPv4/ICMPv6 Packet Classification Encodings"
      assert t[17].name == "MPLS Classification Encodings"

      {:ok, ipv4} = SubTlvSpecs.get_subtlv_specs([22, 9])
      assert ipv4[1].name == "IPv4 Type of Service Range and Mask"
      assert ipv4[7].name == "TCP/UDP Source Port Start"
      assert ipv4[10].name == "TCP/UDP Destination Port End"

      {:ok, ipv6} = SubTlvSpecs.get_subtlv_specs([60, 12])
      assert ipv6[4].name == "IPv6 Source Address"
      assert ipv6[4].value_type == :ipv6

      {:ok, icmp} = SubTlvSpecs.get_subtlv_specs([23, 16])
      assert icmp[1].name == "ICMPv4/ICMPv6 Type Start"
    end
  end

  describe "DOCSIS Extension Field (43.x) per MULPI C.1.1.18" do
    test "43 subtypes are named and typed" do
      {:ok, t} = SubTlvSpecs.get_subtlv_specs(43)
      assert t[6].name == "Extended CMTS MIC Configuration"
      assert t[8].name == "Vendor ID Encoding"
      assert t[8].value_type == :vendor_oui
      assert t[11].name == "Service Type Identifier"
      assert t[12].name == "DEMARC Auto Configuration"
      refute Map.has_key?(t, 13), "43.13 is not assigned per CANN"
    end

    test "43.x subtype tables resolve by path suffix in any context" do
      for prefix <- [[], [22], [24]] do
        assert {:ok, ecm} = SubTlvSpecs.get_subtlv_specs(prefix ++ [43, 6])
        assert ecm[1].name == "Extended CMTS MIC HMAC Type"

        assert {:ok, dac} = SubTlvSpecs.get_subtlv_specs(prefix ++ [43, 12])
        assert dac[1].name == "DAC Disable/Enable Configuration"
        assert dac[3].value_type == :string_null
      end
    end

    test "L2VPN (43.5) subtree per CANN 11.1.2.1" do
      {:ok, l2vpn} = SubTlvSpecs.get_subtlv_specs([22, 43, 5])
      assert l2vpn[1].name == "VPN Identifier"
      assert l2vpn[2].name == "NSI Encapsulation Subtype"
      assert l2vpn[24].name == "L2VPN SOAM Subtype"
      assert l2vpn[26].name == "L2VPN DSID"

      {:ok, nsi} = SubTlvSpecs.get_subtlv_specs([22, 43, 5, 2])
      assert nsi[4].name == "MPLS PW Encapsulation"
      assert nsi[6].name == "IEEE 802.1ah Encapsulation"

      {:ok, soam} = SubTlvSpecs.get_subtlv_specs([24, 43, 5, 24])
      assert soam[1].name == "MEP Configuration"
    end
  end

  describe "get_subtlv_info/2" do
    test "returns info for known sub-TLVs" do
      assert {:ok, info} = SubTlvSpecs.get_subtlv_info(5, 1)
      assert info.name == "Concatenation Support"
    end

    test "returns error for unknown sub-TLV of a known parent" do
      assert {:error, :unknown_subtlv} = SubTlvSpecs.get_subtlv_info(64, 999)
    end

    test "returns error for parent without sub-TLVs" do
      assert {:error, :unknown_tlv} = SubTlvSpecs.get_subtlv_info(66, 1)
    end
  end

  describe "supports_subtlvs?/1" do
    test "true for compound parents, false for simple values" do
      assert SubTlvSpecs.supports_subtlvs?(22)
      assert SubTlvSpecs.supports_subtlvs?(64)
      assert SubTlvSpecs.supports_subtlvs?(202)
      refute SubTlvSpecs.supports_subtlvs?(62)
      refute SubTlvSpecs.supports_subtlvs?(66)
    end
  end

  describe "spec hygiene" do
    test "every sub-TLV entry has a name, value_type and description" do
      parents = [4, 5, 17, 22, 24, 26, 41, 43, 53, 54, 56, 64, 65, 67, 69, 72, 73, 74, 79, 202]

      for parent <- parents do
        {:ok, subtlvs} = SubTlvSpecs.get_subtlv_specs(parent)

        for {sub_type, spec} <- subtlvs do
          assert is_binary(spec.name) and spec.name != "",
                 "TLV #{parent}.#{sub_type} missing name"

          assert is_atom(spec.value_type),
                 "TLV #{parent}.#{sub_type} missing value_type"

          assert is_binary(spec.description) and spec.description != "",
                 "TLV #{parent}.#{sub_type} missing description"

          refute String.starts_with?(spec.name, "Sub-TLV"),
                 "TLV #{parent}.#{sub_type} has a placeholder name"
        end
      end
    end
  end
end
