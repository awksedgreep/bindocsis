defmodule Bindocsis.MtaSpecsTest do
  @moduledoc """
  DO NOT REMOVE: the MTA TLV table must match PKT-SP-PROV1.5-C01-191120 §9.1.

  This table used to list TLVs 1-5 and 64-85 ("MTA Configuration File",
  "Kerberos Realm", "Line Package", "Lawful Intercept", ...) that no
  PacketCable specification defines, and it gave TLV 64 the wrong meaning.
  CLAUDE.md: TLVs must come from the specifications. Do not add a type here
  without a section reference.
  """
  use ExUnit.Case, async: true
  doctest Bindocsis.MtaSpecs

  alias Bindocsis.MtaSpecs

  @spec_types [6, 7, 11, 38, 43, 64, 254]

  test "the table holds exactly the spec-defined types, for every version" do
    for version <- ["1.0", "1.5", "2.0"] do
      assert MtaSpecs.get_supported_types(version) == @spec_types
    end
  end

  test "types the spec does not define are not supported" do
    for type <- [1, 2, 3, 4, 5, 65, 69, 84, 85, 200, 255] do
      refute MtaSpecs.valid_tlv_type?(type)
      assert {:error, :unsupported_type} = MtaSpecs.get_tlv_info(type)
      assert MtaSpecs.get_tlv_name(type) == nil
    end
  end

  test "PROV1.5 §9.1 names and lengths" do
    assert MtaSpecs.get_tlv_name(254) == "Telephony Config File Delimiter"
    assert MtaSpecs.get_tlv_name(11) == "SNMP MIB Object"
    assert MtaSpecs.get_tlv_name(64) == "SNMP MIB Object Long"
    assert MtaSpecs.get_tlv_name(38) == "SNMP Notification Receiver"
    assert MtaSpecs.get_tlv_name(43) == "Vendor Specific"

    assert MtaSpecs.get_tlv_max_length(254) == 1
    assert MtaSpecs.get_tlv_max_length(11) == 254
    assert MtaSpecs.get_tlv_max_length(64) == 65_535

    assert MtaSpecs.get_tlv_value_type(11) == :asn1_der
    assert MtaSpecs.get_tlv_value_type(64) == :asn1_der
  end

  test "max lengths agree with the wire codec" do
    for type <- @spec_types, type not in [6, 7] do
      assert MtaSpecs.get_tlv_max_length(type) <= Bindocsis.MtaTlvLength.max_length(type)
    end
  end

  test "composite types support sub-TLVs; SNMP objects and markers do not" do
    assert MtaSpecs.supports_subtlvs?(38)
    assert MtaSpecs.supports_subtlvs?(43)
    refute MtaSpecs.supports_subtlvs?(11)
    refute MtaSpecs.supports_subtlvs?(64)
    refute MtaSpecs.supports_subtlvs?(254)
  end

  test "only the PacketCable-defined types are MTA-specific" do
    assert MtaSpecs.get_mta_specific_types() == [64, 254]
    assert MtaSpecs.mta_specific?(254)
    refute MtaSpecs.mta_specific?(11)
    refute MtaSpecs.mta_specific?(84)
  end

  test "every entry has a description" do
    for type <- @spec_types do
      assert is_binary(MtaSpecs.get_tlv_description(type))
      assert MtaSpecs.get_tlv_introduced_version(type) == "1.0"
    end
  end
end
