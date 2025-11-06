defmodule Bindocsis.MtaSpecsTest do
  use ExUnit.Case, async: true

  alias Bindocsis.MtaSpecs

  doctest MtaSpecs

  describe "get_tlv_info/2" do
    test "returns info for valid MTA-specific TLV" do
      # MTAConfigurationFile
      assert {:ok, info} = MtaSpecs.get_tlv_info(64, "2.0")
      assert info.name == "MTA Configuration File"
      assert info.description == "PacketCable MTA configuration parameters"
      assert info.introduced_version == "1.0"
      assert info.subtlv_support == true
      assert info.value_type == :compound
      assert info.max_length == :unlimited
      assert info.mta_specific == true
    end

    test "returns info for shared DOCSIS TLV" do
      # NetworkAccessControl
      assert {:ok, info} = MtaSpecs.get_tlv_info(3, "2.0")
      assert info.name == "Network Access Control"
      assert info.description == "Enable/disable network access for the MTA"
      assert info.introduced_version == "1.0"
      assert info.subtlv_support == false
      assert info.value_type == :boolean
      assert info.max_length == 1
      assert info.mta_specific == false
    end

    test "returns info for voice-specific TLVs" do
      # VoiceConfiguration
      assert {:ok, info} = MtaSpecs.get_tlv_info(65, "2.0")
      assert info.name == "Voice Configuration"
      assert info.mta_specific == true
      assert info.subtlv_support == true

      # KerberosRealm
      assert {:ok, info} = MtaSpecs.get_tlv_info(69, "2.0")
      assert info.name == "Kerberos Realm"
      assert info.value_type == :string
      assert info.max_length == 255
    end

    test "returns error for unsupported TLV type" do
      assert {:error, :unsupported_type} = MtaSpecs.get_tlv_info(999, "2.0")
    end

    test "returns error for TLV not supported in version" do
      # TLV 80 is PacketCable 2.0, should not be supported in 1.0
      assert {:error, :unsupported_version} = MtaSpecs.get_tlv_info(80, "1.0")
    end

    test "supports PacketCable version filtering" do
      # TLV 73 is introduced in PacketCable 1.5
      assert {:ok, _} = MtaSpecs.get_tlv_info(73, "1.5")
      assert {:ok, _} = MtaSpecs.get_tlv_info(73, "2.0")
      assert {:error, :unsupported_version} = MtaSpecs.get_tlv_info(73, "1.0")
    end
  end

  describe "get_spec/1" do
    test "returns PacketCable 1.0 specification" do
      spec = MtaSpecs.get_spec("1.0")
      assert is_map(spec)

      # Should include basic TLVs
      # NetworkAccessControl
      assert Map.has_key?(spec, 3)
      # MTAConfigurationFile
      assert Map.has_key?(spec, 64)

      # Should not include 1.5+ TLVs
      # TicketControl (1.5+)
      refute Map.has_key?(spec, 73)
      # VoiceProfile (2.0+)
      refute Map.has_key?(spec, 80)
    end

    test "returns PacketCable 1.5 specification" do
      spec = MtaSpecs.get_spec("1.5")
      assert is_map(spec)

      # Should include 1.0 and 1.5 TLVs
      # MTAConfigurationFile (1.0)
      assert Map.has_key?(spec, 64)
      # TicketControl (1.5)
      assert Map.has_key?(spec, 73)

      # Should not include 2.0+ TLVs
      # VoiceProfile (2.0)
      refute Map.has_key?(spec, 80)
    end

    test "returns PacketCable 2.0 specification" do
      spec = MtaSpecs.get_spec("2.0")
      assert is_map(spec)

      # Should include all TLVs
      # MTAConfigurationFile (1.0)
      assert Map.has_key?(spec, 64)
      # TicketControl (1.5)
      assert Map.has_key?(spec, 73)
      # VoiceProfile (2.0)
      assert Map.has_key?(spec, 80)
    end

    test "defaults to latest version for unknown version" do
      spec_unknown = MtaSpecs.get_spec("99.0")
      spec_2_0 = MtaSpecs.get_spec("2.0")

      assert spec_unknown == spec_2_0
    end
  end

  describe "valid_tlv_type?/2" do
    test "validates MTA-specific TLV types" do
      # MTAConfigurationFile
      assert MtaSpecs.valid_tlv_type?(64, "2.0")
      # VoiceConfiguration
      assert MtaSpecs.valid_tlv_type?(65, "2.0")
      # KerberosRealm
      assert MtaSpecs.valid_tlv_type?(69, "2.0")
    end

    test "validates shared DOCSIS TLV types" do
      # NetworkAccessControl
      assert MtaSpecs.valid_tlv_type?(3, "2.0")
      # CMMIC
      assert MtaSpecs.valid_tlv_type?(6, "2.0")
      # CMTSMIC
      assert MtaSpecs.valid_tlv_type?(7, "2.0")
    end

    test "rejects invalid TLV types" do
      refute MtaSpecs.valid_tlv_type?(999, "2.0")
      refute MtaSpecs.valid_tlv_type?(-1, "2.0")
    end

    test "respects version constraints" do
      # TicketControl in 1.5+
      assert MtaSpecs.valid_tlv_type?(73, "1.5")
      # TicketControl not in 1.0
      refute MtaSpecs.valid_tlv_type?(73, "1.0")

      # VoiceProfile in 2.0+
      assert MtaSpecs.valid_tlv_type?(80, "2.0")
      # VoiceProfile not in 1.5
      refute MtaSpecs.valid_tlv_type?(80, "1.5")
    end

    test "defaults to version 2.0" do
      # When no version specified, should use 2.0
      # VoiceProfile available in 2.0
      assert MtaSpecs.valid_tlv_type?(80)
    end
  end

  describe "get_supported_types/1" do
    test "returns supported types for PacketCable 1.0" do
      types = MtaSpecs.get_supported_types("1.0")
      assert is_list(types)
      # Should be sorted
      assert Enum.sort(types) == types

      # NetworkAccessControl
      assert 3 in types
      # MTAConfigurationFile
      assert 64 in types
      # TicketControl (1.5+)
      refute 73 in types
      # VoiceProfile (2.0+)
      refute 80 in types
    end

    test "returns supported types for PacketCable 2.0" do
      types = MtaSpecs.get_supported_types("2.0")
      assert is_list(types)

      # MTAConfigurationFile (1.0)
      assert 64 in types
      # TicketControl (1.5)
      assert 73 in types
      # VoiceProfile (2.0)
      assert 80 in types
    end

    test "defaults to version 2.0" do
      types_default = MtaSpecs.get_supported_types()
      types_2_0 = MtaSpecs.get_supported_types("2.0")

      assert types_default == types_2_0
    end
  end

  describe "get_tlv_name/2" do
    test "returns names for MTA-specific TLVs" do
      assert MtaSpecs.get_tlv_name(64, "2.0") == "MTA Configuration File"
      assert MtaSpecs.get_tlv_name(65, "2.0") == "Voice Configuration"
      assert MtaSpecs.get_tlv_name(69, "2.0") == "Kerberos Realm"
    end

    test "returns names for shared DOCSIS TLVs" do
      assert MtaSpecs.get_tlv_name(3, "2.0") == "Network Access Control"
      assert MtaSpecs.get_tlv_name(6, "2.0") == "CM MIC"
      assert MtaSpecs.get_tlv_name(7, "2.0") == "CMTS MIC"
    end

    test "returns nil for unsupported TLV types" do
      assert MtaSpecs.get_tlv_name(999, "2.0") == nil
    end

    test "returns nil for version-incompatible TLVs" do
      # VoiceProfile not in 1.0
      assert MtaSpecs.get_tlv_name(80, "1.0") == nil
    end
  end

  describe "supports_subtlvs?/2" do
    test "identifies compound TLVs correctly" do
      # MTAConfigurationFile
      assert MtaSpecs.supports_subtlvs?(64, "2.0")
      # VoiceConfiguration
      assert MtaSpecs.supports_subtlvs?(65, "2.0")
      # ClassOfService
      assert MtaSpecs.supports_subtlvs?(4, "2.0")
    end

    test "identifies simple TLVs correctly" do
      # NetworkAccessControl
      refute MtaSpecs.supports_subtlvs?(3, "2.0")
      # KerberosRealm
      refute MtaSpecs.supports_subtlvs?(69, "2.0")
      # DNSServer
      refute MtaSpecs.supports_subtlvs?(70, "2.0")
    end

    test "returns false for unsupported TLVs" do
      refute MtaSpecs.supports_subtlvs?(999, "2.0")
    end
  end

  describe "get_tlv_description/2" do
    test "returns descriptions for MTA TLVs" do
      desc = MtaSpecs.get_tlv_description(64, "2.0")
      assert desc == "PacketCable MTA configuration parameters"

      desc = MtaSpecs.get_tlv_description(69, "2.0")
      assert desc == "Kerberos realm configuration for secure provisioning"
    end

    test "returns nil for unsupported TLVs" do
      assert MtaSpecs.get_tlv_description(999, "2.0") == nil
    end
  end

  describe "get_tlv_value_type/2" do
    test "returns correct value types" do
      # NetworkAccessControl
      assert MtaSpecs.get_tlv_value_type(3, "2.0") == :boolean
      # MTAConfigurationFile
      assert MtaSpecs.get_tlv_value_type(64, "2.0") == :compound
      # KerberosRealm
      assert MtaSpecs.get_tlv_value_type(69, "2.0") == :string
      # DNSServer
      assert MtaSpecs.get_tlv_value_type(70, "2.0") == :ipv4
      # MTAMACAddress
      assert MtaSpecs.get_tlv_value_type(78, "2.0") == :mac
      # MTAIPProvisioningMode
      assert MtaSpecs.get_tlv_value_type(71, "2.0") == :uint8
    end

    test "returns nil for unsupported TLVs" do
      assert MtaSpecs.get_tlv_value_type(999, "2.0") == nil
    end
  end

  describe "get_tlv_max_length/2" do
    test "returns correct max lengths" do
      # NetworkAccessControl
      assert MtaSpecs.get_tlv_max_length(3, "2.0") == 1
      # MTAConfigurationFile
      assert MtaSpecs.get_tlv_max_length(64, "2.0") == :unlimited
      # KerberosRealm
      assert MtaSpecs.get_tlv_max_length(69, "2.0") == 255
      # DNSServer
      assert MtaSpecs.get_tlv_max_length(70, "2.0") == 4
      # MTAMACAddress
      assert MtaSpecs.get_tlv_max_length(78, "2.0") == 6
    end

    test "returns nil for unsupported TLVs" do
      assert MtaSpecs.get_tlv_max_length(999, "2.0") == nil
    end
  end

  describe "get_tlv_introduced_version/1" do
    test "returns correct introduction versions" do
      # MTAConfigurationFile
      assert MtaSpecs.get_tlv_introduced_version(64) == "1.0"
      # TicketControl
      assert MtaSpecs.get_tlv_introduced_version(73) == "1.5"
      # VoiceProfile
      assert MtaSpecs.get_tlv_introduced_version(80) == "2.0"
    end

    test "returns nil for unsupported TLVs" do
      assert MtaSpecs.get_tlv_introduced_version(999) == nil
    end
  end

  describe "mta_specific?/1" do
    test "identifies MTA-specific TLVs" do
      # MTAConfigurationFile
      assert MtaSpecs.mta_specific?(64)
      # VoiceConfiguration
      assert MtaSpecs.mta_specific?(65)
      # KerberosRealm
      assert MtaSpecs.mta_specific?(69)
      # MTAMACAddress
      assert MtaSpecs.mta_specific?(78)
      # ModemCapabilities (marked as MTA-specific)
      assert MtaSpecs.mta_specific?(5)
    end

    test "identifies shared DOCSIS TLVs" do
      # NetworkAccessControl
      refute MtaSpecs.mta_specific?(3)
      # CMMIC
      refute MtaSpecs.mta_specific?(6)
      # CMTSMIC
      refute MtaSpecs.mta_specific?(7)
      # VendorSpecific
      refute MtaSpecs.mta_specific?(200)
    end

    test "returns false for unsupported TLVs" do
      refute MtaSpecs.mta_specific?(999)
    end
  end

  describe "get_mta_specific_types/0" do
    test "returns list of MTA-specific TLV types" do
      types = MtaSpecs.get_mta_specific_types()
      assert is_list(types)
      # Should be sorted
      assert Enum.sort(types) == types

      # Should include known MTA-specific TLVs
      # ModemCapabilities
      assert 5 in types
      # MTAConfigurationFile
      assert 64 in types
      # VoiceConfiguration
      assert 65 in types
      # KerberosRealm
      assert 69 in types
      # MTAMACAddress
      assert 78 in types

      # Should not include shared DOCSIS TLVs
      # NetworkAccessControl
      refute 3 in types
      # CMMIC
      refute 6 in types
      # CMTSMIC
      refute 7 in types
    end

    test "only includes TLVs marked as MTA-specific" do
      types = MtaSpecs.get_mta_specific_types()

      Enum.each(types, fn type ->
        assert MtaSpecs.mta_specific?(type), "TLV #{type} should be MTA-specific"
      end)
    end
  end

  describe "version support and filtering" do
    test "correctly implements version precedence" do
      # PacketCable 1.0 TLVs should be available in all versions
      pc_1_0_tlvs = [64, 65, 69, 70, 75, 76, 77, 78, 79, 83, 84, 85]

      Enum.each(pc_1_0_tlvs, fn type ->
        assert MtaSpecs.valid_tlv_type?(type, "1.0")
        assert MtaSpecs.valid_tlv_type?(type, "1.5")
        assert MtaSpecs.valid_tlv_type?(type, "2.0")
      end)

      # PacketCable 1.5 TLVs should not be available in 1.0
      pc_1_5_tlvs = [73, 74, 81, 82]

      Enum.each(pc_1_5_tlvs, fn type ->
        refute MtaSpecs.valid_tlv_type?(type, "1.0")
        assert MtaSpecs.valid_tlv_type?(type, "1.5")
        assert MtaSpecs.valid_tlv_type?(type, "2.0")
      end)

      # PacketCable 2.0 TLVs should only be available in 2.0
      pc_2_0_tlvs = [80]

      Enum.each(pc_2_0_tlvs, fn type ->
        refute MtaSpecs.valid_tlv_type?(type, "1.0")
        refute MtaSpecs.valid_tlv_type?(type, "1.5")
        assert MtaSpecs.valid_tlv_type?(type, "2.0")
      end)
    end

    test "spec filtering works correctly" do
      spec_1_0 = MtaSpecs.get_spec("1.0")
      spec_1_5 = MtaSpecs.get_spec("1.5")
      spec_2_0 = MtaSpecs.get_spec("2.0")

      # 1.5 spec should be a superset of 1.0 spec
      Enum.each(spec_1_0, fn {type, _info} ->
        assert Map.has_key?(spec_1_5, type)
      end)

      # 2.0 spec should be a superset of 1.5 spec
      Enum.each(spec_1_5, fn {type, _info} ->
        assert Map.has_key?(spec_2_0, type)
      end)

      # Each higher version should have more TLVs
      assert map_size(spec_1_0) < map_size(spec_1_5)
      assert map_size(spec_1_5) < map_size(spec_2_0)
    end
  end

  describe "TLV information consistency" do
    test "all MTA-specific TLVs have correct mta_specific flag" do
      mta_types = MtaSpecs.get_mta_specific_types()

      Enum.each(mta_types, fn type ->
        {:ok, info} = MtaSpecs.get_tlv_info(type, "2.0")
        assert info.mta_specific == true, "TLV #{type} should have mta_specific=true"
      end)
    end

    test "compound TLVs have correct value_type and subtlv_support" do
      compound_types = [64, 65, 66, 67, 68, 72, 73, 75, 80, 81, 82, 83, 84]

      Enum.each(compound_types, fn type ->
        if MtaSpecs.valid_tlv_type?(type, "2.0") do
          {:ok, info} = MtaSpecs.get_tlv_info(type, "2.0")
          assert info.value_type == :compound, "TLV #{type} should have value_type=:compound"
          assert info.subtlv_support == true, "TLV #{type} should support sub-TLVs"
          assert info.max_length == :unlimited, "TLV #{type} should have unlimited max_length"
        end
      end)
    end

    test "simple TLVs have correct value_type and subtlv_support" do
      simple_types = [3, 6, 7, 69, 70, 71, 74, 76, 77, 78, 79, 85]

      Enum.each(simple_types, fn type ->
        if MtaSpecs.valid_tlv_type?(type, "2.0") do
          {:ok, info} = MtaSpecs.get_tlv_info(type, "2.0")
          assert info.value_type != :compound, "TLV #{type} should not have value_type=:compound"
          assert info.subtlv_support == false, "TLV #{type} should not support sub-TLVs"
          assert info.max_length != :unlimited, "TLV #{type} should have finite max_length"
        end
      end)
    end
  end
end
