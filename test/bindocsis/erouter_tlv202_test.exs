defmodule Bindocsis.ERouterTlv202Test do
  use ExUnit.Case
  alias Bindocsis.SubTlvSpecs

  @moduledoc """
  Tests for eRouter (TLV 202) sub-TLV specifications and round-trip parity.

  Spec references: CableLabs CM-SP-eRouter (transposed as ETSI ES 203 386
  V1.1.1) Annex B.4 "eRouter configuration encodings".
  """

  describe "TLV 202 (eRouter) sub-TLV specs" do
    test "has named specs for all Annex B.4 encodings" do
      assert {:ok, subtlvs} = SubTlvSpecs.get_subtlv_specs(202)

      assert subtlvs[1].name == "eRouter Initialization Mode"
      assert subtlvs[1].value_type == :uint8
      assert subtlvs[1].enum_values[0] == "Disabled"
      assert subtlvs[1].enum_values[3] == "Dual IP Protocol Enabled"

      assert subtlvs[2].name == "TR-069 Management Server"
      assert subtlvs[2].value_type == :compound

      assert subtlvs[3].name == "eRouter Initialization Mode Override"
      assert subtlvs[10].name == "RA Transmission Interval"
      assert subtlvs[10].value_type == :uint16
      assert subtlvs[11].name == "SNMP MIB Object"
      assert subtlvs[12].name == "IP Multicast Configuration Server"
      assert subtlvs[12].value_type == :string
      assert subtlvs[13].name == "Link ID Control"

      assert subtlvs[42].name == "Topology Mode"
      assert subtlvs[42].enum_values[1] == "Favor Depth"
      assert subtlvs[42].enum_values[2] == "Favor Width"

      assert subtlvs[43].name == "Vendor Specific Information"
      assert subtlvs[43].value_type == :compound
      assert subtlvs[53].name == "SNMPv1v2c Coexistence Configuration"
      assert subtlvs[53].value_type == :compound
      assert subtlvs[54].name == "SNMPv3 Access View Configuration"
      assert subtlvs[54].value_type == :compound
    end

    test "TLV 202.2 (TR-069 Management Server) has named sub-TLVs per B.4.3" do
      assert {:ok, subtlvs} = SubTlvSpecs.get_subtlv_specs([202, 2])

      assert subtlvs[1].name == "EnableCWMP"
      assert subtlvs[1].value_type == :uint8
      assert subtlvs[2].name == "URL"
      assert subtlvs[2].value_type == :string
      assert subtlvs[3].name == "Username"
      assert subtlvs[4].name == "Password"
      assert subtlvs[5].name == "ConnectionRequestUsername"
      assert subtlvs[6].name == "ConnectionRequestPassword"
      assert subtlvs[7].name == "ACSOverride"
      assert subtlvs[7].value_type == :uint8
    end

    test "TLV 202.43 (Vendor Specific) has Vendor ID sub-TLV per B.4.7" do
      assert {:ok, subtlvs} = SubTlvSpecs.get_subtlv_specs([202, 43])
      assert subtlvs[8].name == "Vendor ID"
      assert subtlvs[8].value_type == :vendor_oui
    end

    test "TLV 202.53 (SNMPv1v2c Coexistence) has sub-TLVs per B.4.5" do
      assert {:ok, subtlvs} = SubTlvSpecs.get_subtlv_specs([202, 53])
      assert subtlvs[1].name == "SNMPv1v2c Community Name"
      assert subtlvs[2].name == "SNMPv1v2c Transport Address Access"
      assert subtlvs[2].value_type == :compound
      assert subtlvs[3].name == "SNMPv1v2c Access View Type"
      assert subtlvs[4].name == "SNMPv1v2c Access View Name"

      assert {:ok, nested} = SubTlvSpecs.get_subtlv_specs([202, 53, 2])
      assert nested[1].name == "SNMPv1v2c Transport Address"
      assert nested[2].name == "SNMPv1v2c Transport Address Mask"
    end

    test "TLV 202.54 (SNMPv3 Access View) has sub-TLVs per B.4.6" do
      assert {:ok, subtlvs} = SubTlvSpecs.get_subtlv_specs([202, 54])
      assert subtlvs[1].name == "SNMPv3 Access View Name"
      assert subtlvs[2].name == "SNMPv3 Access View Subtree"
      assert subtlvs[3].name == "SNMPv3 Access View Mask"
      assert subtlvs[4].name == "SNMPv3 Access View Type"
    end
  end

  describe "TLV 202 enrichment" do
    setup do
      url = "http://acs.example.com/cwmp"
      user = "acsuser"
      pass = "acspass"
      cr_user = "cpe-user"
      cr_pass = "cpe-pass"

      tr069 =
        <<1, 1, 1>> <>
          <<2, byte_size(url)::8, url::binary>> <>
          <<3, byte_size(user)::8, user::binary>> <>
          <<4, byte_size(pass)::8, pass::binary>> <>
          <<5, byte_size(cr_user)::8, cr_user::binary>> <>
          <<6, byte_size(cr_pass)::8, cr_pass::binary>> <>
          <<7, 1, 1>>

      value = <<1, 1, 3>> <> <<2, byte_size(tr069)::8, tr069::binary>> <> <<3, 1, 0>>
      binary = <<202, byte_size(value)::8, value::binary>> <> <<255>>

      {:ok, binary: binary, url: url}
    end

    test "parses eRouter block into named, typed fields", %{binary: binary, url: url} do
      {:ok, tlvs} = Bindocsis.parse(binary, format: :binary, enhanced: true)
      tlv = Enum.find(tlvs, &(&1.type == 202))

      assert tlv.name == "eRouter"
      assert tlv.value_type == :compound

      init_mode = Enum.find(tlv.subtlvs, &(&1.type == 1))
      assert init_mode.name == "eRouter Initialization Mode"
      assert init_mode.formatted_value == "Dual IP Protocol Enabled"

      tr069 = Enum.find(tlv.subtlvs, &(&1.type == 2))
      assert tr069.name == "TR-069 Management Server"
      assert tr069.value_type == :compound

      by_type = Map.new(tr069.subtlvs, &{&1.type, &1})
      assert by_type[1].name == "EnableCWMP"
      assert by_type[1].formatted_value == "1"
      assert by_type[2].name == "URL"
      assert by_type[2].formatted_value == url
      assert by_type[3].name == "Username"
      assert by_type[5].name == "ConnectionRequestUsername"
      assert by_type[5].formatted_value == "cpe-user"
      assert by_type[6].name == "ConnectionRequestPassword"
      assert by_type[7].name == "ACSOverride"
      assert by_type[7].formatted_value == "1"
    end

    test "compound parsing survives ACS URL text in payload", %{binary: binary} do
      # An ACS URL contains "//" which the text heuristic flags; spec-declared
      # compound TLVs must still be parsed as compound.
      {:ok, tlvs} = Bindocsis.parse(binary, format: :binary, enhanced: true)
      tlv = Enum.find(tlvs, &(&1.type == 202))
      assert is_list(tlv.subtlvs) and length(tlv.subtlvs) == 3
    end

    test "JSON round-trip is byte-correct", %{binary: binary} do
      {:ok, tlvs} = Bindocsis.parse(binary, format: :binary, enhanced: true)
      {:ok, json} = Bindocsis.generate(tlvs, format: :json)
      {:ok, tlvs2} = Bindocsis.parse(json, format: :json)
      {:ok, binary2} = Bindocsis.generate(tlvs2, format: :binary)
      assert binary2 == binary
    end

    test "YAML round-trip is byte-correct", %{binary: binary} do
      {:ok, tlvs} = Bindocsis.parse(binary, format: :binary, enhanced: true)
      {:ok, yaml} = Bindocsis.generate(tlvs, format: :yaml)
      {:ok, tlvs2} = Bindocsis.parse(yaml, format: :yaml)
      {:ok, binary2} = Bindocsis.generate(tlvs2, format: :binary)
      assert binary2 == binary
    end

    test "editing the ACS URL via JSON re-encodes correctly", %{binary: binary, url: url} do
      new_url = "https://acs2.example.net/path"

      {:ok, tlvs} = Bindocsis.parse(binary, format: :binary, enhanced: true)
      {:ok, json} = Bindocsis.generate(tlvs, format: :json)
      edited_json = String.replace(json, url, new_url)

      {:ok, tlvs2} = Bindocsis.parse(edited_json, format: :json)
      {:ok, binary2} = Bindocsis.generate(tlvs2, format: :binary)

      {:ok, reparsed} = Bindocsis.parse(binary2, format: :binary, enhanced: true)
      tlv = Enum.find(reparsed, &(&1.type == 202))
      tr069 = Enum.find(tlv.subtlvs, &(&1.type == 2))
      url_subtlv = Enum.find(tr069.subtlvs, &(&1.type == 2))

      assert url_subtlv.name == "URL"
      assert url_subtlv.value == new_url
      assert url_subtlv.length == byte_size(new_url)
    end
  end
end
