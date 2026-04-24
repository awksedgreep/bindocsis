defmodule Bindocsis.DocsisConfigfileYamlParserTest do
  use ExUnit.Case

  @docsis_configfile_yaml """
  ---
  MtaConfigDelimiter:
  - 1
  - 255
  VendorSpecific:
    id: '0x0015a2'
    options:
    - 69
    - '0x0102'
  SnmpMibObject:
  - INTEGER: 1
    oid: 1.3.6.1.4.1.4491.2.2.1.1.1.7.0
  """

  describe "parse/2" do
    test "parses docsis-configfile YAML format explicitly" do
      assert {:ok, tlvs} =
               Bindocsis.parse(@docsis_configfile_yaml, format: :docsis_configfile_yaml)

      assert Enum.map(tlvs, & &1.type) == [254, 11, 43, 254]
      assert hd(tlvs).value == <<1>>
      assert List.last(tlvs).value == <<255>>

      snmp_tlv = Enum.at(tlvs, 1)
      assert snmp_tlv.type == 11
      assert byte_size(snmp_tlv.value) > 0

      vendor_tlv = Enum.at(tlvs, 2)
      assert vendor_tlv.type == 43
      assert vendor_tlv.value == <<8, 3, 0x00, 0x15, 0xA2, 69, 2, 0x01, 0x02>>
    end

    test "keeps native yaml behavior unchanged" do
      native_yaml = "tlvs:\n  - type: 3\n    formatted_value: \"1\"\n"

      assert {:ok, [%{type: 3, length: 1, value: <<1>>}]} =
               Bindocsis.parse(native_yaml, format: :yaml)
    end

    test "rejects unsupported docsis-configfile keys" do
      yaml = """
      ---
      KerberosRealm: EXAMPLE.COM
      """

      assert {:error, error} = Bindocsis.parse(yaml, format: :docsis_configfile_yaml)
      assert String.contains?(error, "Unsupported docsis-configfile YAML keys")
    end
  end

  describe "convert/2" do
    test "converts docsis-configfile YAML to mta binary with passthrough options" do
      assert {:ok, binary} =
               Bindocsis.convert(
                 @docsis_configfile_yaml,
                 from: :docsis_configfile_yaml,
                 to: :mta,
                 terminate: false
               )

      assert is_binary(binary)
      assert binary_part(binary, 0, 3) == <<254, 1, 1>>
      assert binary_part(binary, byte_size(binary) - 3, 3) == <<254, 1, 255>>
    end

    test "passes legacy MTA length encoding options through conversion" do
      large_option = String.duplicate("aa", 193)

      yaml = """
      ---
      VendorSpecific:
        id: '0x0015a2'
        options:
        - 69
        - '0x#{large_option}'
      """

      assert {:ok, binary} =
               Bindocsis.convert(
                 yaml,
                 from: :docsis_configfile_yaml,
                 to: :mta,
                 terminate: false,
                 length_encoding: :docsis_configfile_legacy
               )

      assert <<43, 200, _::binary>> = binary
    end
  end

  describe "parse_file/2" do
    test "auto-detects docsis-configfile yaml files" do
      test_file = Path.join(System.tmp_dir!(), "docsis_configfile_auto.yaml")
      File.write!(test_file, @docsis_configfile_yaml)

      try do
        assert {:ok, tlvs} = Bindocsis.parse_file(test_file)
        assert Enum.map(tlvs, & &1.type) == [254, 11, 43, 254]
      after
        File.rm(test_file)
      end
    end
  end
end
