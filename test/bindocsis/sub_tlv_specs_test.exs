defmodule Bindocsis.SubTlvSpecsTest do
  use ExUnit.Case
  alias Bindocsis.SubTlvSpecs

  describe "extended compound TLV sub-TLVs (66-85)" do
    test "TLV 66 (Management Event Control) has correct sub-TLVs" do
      assert {:ok, subtlvs} = SubTlvSpecs.get_subtlv_specs(66)

      # Should have 4 sub-TLVs
      assert map_size(subtlvs) == 4

      # Check specific sub-TLVs exist
      # Event Priority Threshold
      assert Map.has_key?(subtlvs, 1)
      # Event Reporting Server
      assert Map.has_key?(subtlvs, 2)
      # Event Reporting Port
      assert Map.has_key?(subtlvs, 3)
      # SNMP Trap Community
      assert Map.has_key?(subtlvs, 4)

      # Check sub-TLV 1 details
      priority_subtlv = subtlvs[1]
      assert priority_subtlv.name == "Event Priority Threshold"
      assert priority_subtlv.value_type == :uint8
      assert Map.has_key?(priority_subtlv, :enum_values)
      assert priority_subtlv.enum_values[5] == "Warning"
    end

    test "TLV 67 (Subscriber Management CPE IPv6 Table) has IPv6 sub-TLVs" do
      assert {:ok, subtlvs} = SubTlvSpecs.get_subtlv_specs(67)

      assert map_size(subtlvs) == 3
      assert subtlvs[1].name == "CPE IPv6 Prefix"
      assert subtlvs[1].value_type == :ipv6
      assert subtlvs[2].name == "CPE IPv6 Prefix Length"
      assert subtlvs[2].value_type == :uint8
    end

    test "TLV 70 (Aggregate Service Flow) has service flow sub-TLVs" do
      assert {:ok, subtlvs} = SubTlvSpecs.get_subtlv_specs(70)

      assert map_size(subtlvs) == 4
      assert subtlvs[1].name == "Aggregate Service Flow Reference"
      assert subtlvs[1].value_type == :uint16
      # Service Flow Reference List
      assert subtlvs[2].value_type == :compound
    end

    test "TLV 72 (Metro Ethernet Service Profile) has Ethernet sub-TLVs" do
      assert {:ok, subtlvs} = SubTlvSpecs.get_subtlv_specs(72)

      assert map_size(subtlvs) == 4
      service_type = subtlvs[1]
      assert service_type.name == "Service Type"
      assert service_type.value_type == :uint8
      assert Map.has_key?(service_type, :enum_values)
      assert service_type.enum_values[1] == "EPL (Ethernet Private Line)"
    end

    test "TLV 73 (Network Timing Profile) has timing sub-TLVs" do
      assert {:ok, subtlvs} = SubTlvSpecs.get_subtlv_specs(73)

      assert map_size(subtlvs) == 3
      timing_ref = subtlvs[1]
      assert timing_ref.name == "Timing Reference Source"
      assert Map.has_key?(timing_ref, :enum_values)
      assert timing_ref.enum_values[4] == "Precision Time Protocol (PTP)"
    end

    test "TLV 74 (Energy Parameters) has energy management sub-TLVs" do
      assert {:ok, subtlvs} = SubTlvSpecs.get_subtlv_specs(74)

      assert map_size(subtlvs) == 3
      energy_mode = subtlvs[1]
      assert energy_mode.name == "Energy Management Mode"
      assert Map.has_key?(energy_mode, :enum_values)
      assert energy_mode.enum_values[0] == "Disabled"
      assert energy_mode.enum_values[3] == "Dynamic Power Management"
    end
  end

  describe "extended TLV sub-TLVs (86-199)" do
    test "TLV 86 (eRouter Initialization Mode Override) has eRouter sub-TLVs" do
      assert {:ok, subtlvs} = SubTlvSpecs.get_subtlv_specs(86)

      assert map_size(subtlvs) == 3
      init_mode = subtlvs[1]
      assert init_mode.name == "Initialization Mode"
      assert init_mode.value_type == :uint8
      assert Map.has_key?(init_mode, :enum_values)
      assert init_mode.enum_values[3] == "Dual Stack"

      ipv4_config = subtlvs[2]
      assert ipv4_config.name == "IPv4 Configuration Method"
      assert ipv4_config.enum_values[2] == "DHCP"

      ipv6_config = subtlvs[3]
      assert ipv6_config.name == "IPv6 Configuration Method"
      assert ipv6_config.enum_values[3] == "SLAAC"
    end

    test "TLV 101 (DPD Configuration) has deep packet detection sub-TLVs" do
      assert {:ok, subtlvs} = SubTlvSpecs.get_subtlv_specs(101)

      assert map_size(subtlvs) == 3
      assert subtlvs[1].name == "DPD Enable"
      assert subtlvs[2].name == "Detection Rules"
      assert subtlvs[2].value_type == :compound

      action_policy = subtlvs[3]
      assert action_policy.name == "Action Policy"
      assert Map.has_key?(action_policy, :enum_values)
      assert action_policy.enum_values[4] == "Redirect"
    end

    test "TLV 108 (Extended Modem Capabilities) has DOCSIS 4.0 capabilities" do
      assert {:ok, subtlvs} = SubTlvSpecs.get_subtlv_specs(108)

      assert map_size(subtlvs) == 5
      docsis_40 = subtlvs[1]
      assert docsis_40.name == "DOCSIS 4.0 Support"
      assert Map.has_key?(docsis_40, :enum_values)
      assert docsis_40.enum_values[1] == "Supported"

      lld_support = subtlvs[2]
      assert lld_support.name == "Low Latency DOCSIS Support"

      ofdm_support = subtlvs[5]
      assert ofdm_support.name == "OFDM/OFDMA Support"
      assert ofdm_support.enum_values[3] == "Both OFDM and OFDMA"
    end
  end

  describe "vendor-specific sub-TLVs (200-253)" do
    test "vendor-specific TLVs have basic sub-TLV structure" do
      assert {:ok, subtlvs} = SubTlvSpecs.get_subtlv_specs(200)

      assert map_size(subtlvs) == 2
      assert subtlvs[1].name == "Vendor OUI"
      assert subtlvs[1].value_type == :vendor_oui
      assert subtlvs[2].name == "Vendor Data"
      assert subtlvs[2].value_type == :binary
    end

    test "all vendor-specific TLVs use same sub-TLV structure" do
      vendor_tlv_types = [200, 210, 220, 230, 240, 250, 253]

      for tlv_type <- vendor_tlv_types do
        assert {:ok, subtlvs} = SubTlvSpecs.get_subtlv_specs(tlv_type)
        assert map_size(subtlvs) == 2
        assert subtlvs[1].value_type == :vendor_oui
        assert subtlvs[2].value_type == :binary
      end
    end
  end

  describe "get_subtlv_info/2" do
    test "retrieves specific sub-TLV information" do
      assert {:ok, subtlv_info} = SubTlvSpecs.get_subtlv_info(66, 1)

      assert subtlv_info.name == "Event Priority Threshold"
      assert subtlv_info.description == "Minimum event priority to report"
      assert subtlv_info.value_type == :uint8
      assert subtlv_info.max_length == 1
      assert Map.has_key?(subtlv_info, :enum_values)
    end

    test "returns error for unknown parent TLV" do
      assert {:error, :unknown_tlv} = SubTlvSpecs.get_subtlv_info(999, 1)
    end

    test "returns error for unknown sub-TLV" do
      assert {:error, :unknown_subtlv} = SubTlvSpecs.get_subtlv_info(66, 999)
    end
  end

  describe "completed sub-TLV functions" do
    test "previously stubbed functions now have implementations" do
      # Test that previously stubbed functions now have actual implementations
      implemented_subtlv_tlvs = [
        77,
        79,
        80,
        81,
        82,
        83,
        84,
        85,
        87,
        91,
        97,
        98,
        99,
        102,
        103,
        105,
        106,
        107,
        109,
        110
      ]

      for tlv_type <- implemented_subtlv_tlvs do
        assert {:ok, subtlvs} = SubTlvSpecs.get_subtlv_specs(tlv_type)
        assert map_size(subtlvs) > 0, "TLV #{tlv_type} should have sub-TLV specifications"
      end
    end

    test "some specific implementations have correct structure" do
      # Test TLV 77 (DLS Encoding)
      assert {:ok, subtlvs} = SubTlvSpecs.get_subtlv_specs(77)
      assert map_size(subtlvs) == 4
      assert subtlvs[4].name == "DLS Error Correction"
      assert Map.has_key?(subtlvs[4], :enum_values)

      # Test TLV 83 (DBC Request)
      assert {:ok, subtlvs} = SubTlvSpecs.get_subtlv_specs(83)
      assert map_size(subtlvs) == 4
      assert subtlvs[1].name == "DBC Transaction ID"
      assert subtlvs[1].value_type == :uint32

      # Test TLV 110 (Quality Metrics Collection)
      assert {:ok, subtlvs} = SubTlvSpecs.get_subtlv_specs(110)
      assert map_size(subtlvs) == 6
      assert subtlvs[3].name == "Metric Types"
      assert Map.has_key?(subtlvs[3], :enum_values)
    end
  end

  describe "integration with existing sub-TLV specifications" do
    test "existing sub-TLV specifications still work" do
      # Test that we didn't break existing sub-TLV specs
      # Modem Capabilities
      assert {:ok, subtlvs} = SubTlvSpecs.get_subtlv_specs(5)
      assert map_size(subtlvs) > 0
      # Concatenation Support
      assert Map.has_key?(subtlvs, 1)

      # Downstream Service Flow
      assert {:ok, subtlvs} = SubTlvSpecs.get_subtlv_specs(24)
      assert map_size(subtlvs) > 0

      # L2VPN Encoding
      assert {:ok, subtlvs} = SubTlvSpecs.get_subtlv_specs(43)
      assert map_size(subtlvs) > 0
    end

    test "can retrieve information for existing sub-TLVs" do
      assert {:ok, subtlv_info} = SubTlvSpecs.get_subtlv_info(5, 1)
      assert subtlv_info.name == "Concatenation Support"

      assert {:ok, subtlv_info} = SubTlvSpecs.get_subtlv_info(24, 1)
      assert subtlv_info.name == "Service Flow Reference"
    end
  end

  describe "sub-TLV specification completeness" do
    test "all specified compound TLVs have sub-TLV definitions" do
      # These are the compound TLVs we implemented (66-85)
      implemented_compound_tlvs = [66, 67, 70, 72, 73, 74, 77, 79, 80, 81, 82, 83, 84, 85]

      for tlv_type <- implemented_compound_tlvs do
        assert {:ok, subtlvs} = SubTlvSpecs.get_subtlv_specs(tlv_type)
        assert map_size(subtlvs) > 0, "TLV #{tlv_type} should have sub-TLV specifications"
      end
    end

    test "all specified extended TLVs have sub-TLV definitions" do
      # These are the extended TLVs we implemented (86-110)
      implemented_extended_tlvs = [
        86,
        87,
        91,
        97,
        98,
        99,
        101,
        102,
        103,
        105,
        106,
        107,
        108,
        109,
        110
      ]

      for tlv_type <- implemented_extended_tlvs do
        assert {:ok, subtlvs} = SubTlvSpecs.get_subtlv_specs(tlv_type)
        assert map_size(subtlvs) > 0, "TLV #{tlv_type} should have sub-TLV specifications"
      end
    end

    test "comprehensive coverage statistics" do
      # Count total implemented sub-TLVs
      all_compound_tlvs = [66, 67, 70, 72, 73, 74, 77, 79, 80, 81, 82, 83, 84, 85]
      all_extended_tlvs = [86, 87, 91, 97, 98, 99, 101, 102, 103, 105, 106, 107, 108, 109, 110]

      total_sub_tlvs =
        (all_compound_tlvs ++ all_extended_tlvs)
        |> Enum.map(fn tlv_type ->
          {:ok, subtlvs} = SubTlvSpecs.get_subtlv_specs(tlv_type)
          map_size(subtlvs)
        end)
        |> Enum.sum()

      # Should have implemented hundreds of sub-TLVs
      assert total_sub_tlvs > 100,
             "Should have implemented over 100 sub-TLVs, got #{total_sub_tlvs}"
    end
  end

  describe "enum value quality" do
    test "enum values are comprehensive and meaningful" do
      # Test that enum values provide good coverage
      assert {:ok, subtlvs} = SubTlvSpecs.get_subtlv_specs(66)
      priority_enum = subtlvs[1].enum_values

      # Should have standard syslog priority levels
      assert priority_enum[1] == "Emergency"
      assert priority_enum[4] == "Error"
      assert priority_enum[8] == "Debug"

      # Test Metro Ethernet service types
      assert {:ok, subtlvs} = SubTlvSpecs.get_subtlv_specs(72)
      service_enum = subtlvs[1].enum_values

      # Should have standard MEF service types
      assert String.contains?(service_enum[1], "EPL")
      assert String.contains?(service_enum[2], "EVPL")
      assert String.contains?(service_enum[3], "EP-LAN")
    end
  end
end
