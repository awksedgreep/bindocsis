defmodule DocsisConfigfileYamlGeneratorTest do
  @moduledoc """
  DO NOT REMOVE: MTA binary -> docsis-configfile YAML -> MTA binary is byte-exact.

  This is how an MTA file is edited by hand. The YAML is the dialect that
  eMTA provisioning templates (`<mac>.siptemplate.yaml`) use, so an edited
  file stays in the operator's format. When a file cannot be expressed
  exactly, the generator returns an error rather than YAML that would
  silently change the file. Checked against ~2,500 production eMTA files.
  The fixtures here are synthetic.
  """
  use ExUnit.Case, async: true
  doctest Bindocsis.Generators.DocsisConfigfileYamlGenerator

  alias Bindocsis.Generators.DocsisConfigfileYamlGenerator, as: Gen
  alias Bindocsis.HumanConfig

  @yaml """
  ---
  MtaConfigDelimiter:
  - 1
  - 255
  VendorSpecific:
    id: '0x00000c'
    options:
    - 69
    - '0x0102030405'
  SnmpMibObject:
  - INTEGER: 1
    oid: 1.3.6.1.4.1.4491.2.2.1.1.1.7.0
  - INTEGER: -2
    oid: 1.3.6.1.4.1.99999.1.4.0
  - STRING: 'user-0001'
    oid: 1.3.6.1.4.1.99999.1.1.0
  - STRING: 'it''s not a secret'
    oid: 1.3.6.1.4.1.99999.1.2.0
  - STRING: '0x00ff10'
    oid: 1.3.6.1.4.1.99999.1.5.0
  - IPADDRESS: '192.0.2.10'
    oid: 1.3.6.1.4.1.99999.1.3.0
  - UNSIGNED: 300
    oid: 1.3.6.1.4.1.99999.1.6.0
  - OBJECTID: '1.3.6.1.4.1.99999'
    oid: 1.3.6.1.4.1.99999.1.7.0
  """

  defp mta_binary(yaml \\ @yaml) do
    {:ok, tlvs} = Bindocsis.parse(yaml, format: :docsis_configfile_yaml)
    {:ok, bin} = Bindocsis.generate(tlvs, format: :mta)
    bin
  end

  test "binary -> YAML -> binary is byte-exact for every SNMP value type used" do
    bin = mta_binary()
    {:ok, tlvs} = Bindocsis.parse(bin, format: :mta)
    {:ok, yaml} = Bindocsis.generate(tlvs, format: :docsis_configfile_yaml)

    assert yaml =~ "STRING: 'it''s not a secret'"
    assert yaml =~ "STRING: '0x00ff10'"
    assert {:ok, ^bin} = Bindocsis.convert(yaml, from: :docsis_configfile_yaml, to: :mta)
  end

  test "negative INTEGERs are minimal two's complement (-1 was written as 0)" do
    for {v, bytes} <- [{-1, <<0xFF>>}, {-2, <<0xFE>>}, {-300, <<0xFE, 0xD4>>}, {-128, <<0x80>>}] do
      yaml = "---\nSnmpMibObject:\n- INTEGER: #{v}\n  oid: 1.3.6.1.2.1.1.0\n"
      {:ok, [%{value: value}]} = Bindocsis.parse(yaml, format: :docsis_configfile_yaml)

      assert value ==
               <<0x30, 11 + byte_size(bytes), 6, 7, 43, 6, 1, 2, 1, 1, 0, 2, byte_size(bytes)>> <>
                 bytes
    end
  end

  test "a vendor TLV with only its vendor ID round-trips" do
    yaml =
      "---\nMtaConfigDelimiter:\n- 1\n- 255\nVendorSpecific:\n  id: '0x00000c'\n  options: []\n"

    bin = mta_binary(yaml)
    {:ok, tlvs} = Bindocsis.parse(bin, format: :mta)
    {:ok, out} = Gen.generate(tlvs)
    assert {:ok, ^bin} = Bindocsis.convert(out, from: :docsis_configfile_yaml, to: :mta)
  end

  test "files the dialect cannot express are refused, not converted lossily" do
    bin = mta_binary()
    {:ok, tlvs} = Bindocsis.parse(bin, format: :mta)

    # DOCSIS MIC after the end marker
    mic = %{type: 6, length: 16, value: :binary.copy(<<1>>, 16)}
    assert {:error, msg} = Gen.generate(tlvs ++ [mic])
    assert msg =~ "cannot express TLV type(s) 6"

    # vendor-specific before the SNMP objects (the YAML always writes it after)
    [start | rest] = tlvs
    {vendor, others} = Enum.split_with(rest, &(&1.type == 43))
    assert {:error, msg} = Gen.generate([start | vendor ++ others])
    assert msg =~ "byte for byte"
  end

  test "HumanConfig.to_yaml/from_yaml edit an MTA file in the docsis-configfile dialect" do
    bin = mta_binary()

    assert {:ok, yaml} = HumanConfig.to_yaml(bin)
    assert yaml =~ "MtaConfigDelimiter:"
    assert {:ok, ^bin} = HumanConfig.from_yaml(yaml)

    edited = String.replace(yaml, "'user-0001'", "'user-0002'")
    assert {:ok, new_bin} = HumanConfig.from_yaml(edited)
    assert byte_size(new_bin) == byte_size(bin)
    assert new_bin =~ "user-0002"
  end

  test "HumanConfig.to_yaml refuses an MTA file with a DOCSIS trailer" do
    assert {:error, msg} = HumanConfig.to_yaml(mta_binary() <> <<0xFF, 0, 0>>)
    assert msg =~ "trailer"
  end

  test "HumanConfig keeps DOCSIS YAML on the native format" do
    {:ok, yaml} = HumanConfig.to_yaml(<<3, 1, 1, 255>>)
    assert yaml =~ "tlvs:"
    refute yaml =~ "MtaConfigDelimiter"
  end
end
