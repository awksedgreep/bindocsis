defmodule SnmpVarbindTest do
  @moduledoc """
  DO NOT REMOVE: Bindocsis.SnmpVarbind encodes exactly like docsis-configfile YAML.

  Editors (ddnet's bootfile editor) edit TLV 11/64 variable bindings as
  OID + type + value through this module. A binding edited that way must be
  the same bytes as the same entry written in a `SnmpMibObject` YAML
  template. Fixtures are synthetic.
  """
  use ExUnit.Case, async: true
  doctest Bindocsis.SnmpVarbind

  alias Bindocsis.SnmpVarbind

  @cases [
    {"INTEGER", "1", "1"},
    {"INTEGER", "-2", "-2"},
    {"STRING", "'user-0001'", "user-0001"},
    {"STRING", "'0x00ff10'", "0x00ff10"},
    {"IPADDRESS", "'192.0.2.10'", "192.0.2.10"},
    {"UNSIGNED", "300", "300"},
    {"TIMETICKS", "4294967295", "4294967295"},
    {"OBJECTID", "'1.3.6.1.4.1.99999'", "1.3.6.1.4.1.99999"},
    {"COUNTER64", "18446744073709551615", "18446744073709551615"}
  ]

  defp yaml_value(type, yaml_scalar) do
    yaml = "---\nSnmpMibObject:\n- #{type}: #{yaml_scalar}\n  oid: 1.3.6.1.4.1.99999.1.1.0\n"
    {:ok, [%{value: der}]} = Bindocsis.parse(yaml, format: :docsis_configfile_yaml)
    der
  end

  test "encode/3 gives the YAML dialect's bytes, and decode/1 reverses it" do
    for {type, yaml_scalar, form_value} <- @cases do
      expected = yaml_value(type, yaml_scalar)

      assert {:ok, ^expected} =
               SnmpVarbind.encode("1.3.6.1.4.1.99999.1.1.0", type, form_value),
             "#{type} #{form_value}"

      assert {:ok, %{oid: "1.3.6.1.4.1.99999.1.1.0", type: ^type, value: ^form_value}} =
               SnmpVarbind.decode(expected)
    end
  end

  test "out-of-range numbers are refused instead of being truncated" do
    assert {:error, msg} = SnmpVarbind.encode("1.3.6.1.2.1.1.0", "INTEGER", "2147483648")
    assert msg =~ "between"
    assert {:error, _} = SnmpVarbind.encode("1.3.6.1.2.1.1.0", "UNSIGNED", "-1")
    assert {:error, _} = SnmpVarbind.encode("1.3.6.1.2.1.1.0", "COUNTER", "4294967296")
    assert {:error, _} = SnmpVarbind.encode("1.3.6.1.2.1.1.0", "INTEGER", "seven")
  end

  test "COUNTER64 is unsigned: 0x00 pad above 2^63, never negative" do
    {:ok, der} = SnmpVarbind.encode("1.3.6.1.2.1.1.0", "COUNTER64", "200")
    assert String.ends_with?(der, <<0x46, 2, 0, 200>>)
    assert {:ok, %{value: "200"}} = SnmpVarbind.decode(der)

    yaml = "---\nSnmpMibObject:\n- COUNTER64: -1\n  oid: 1.3.6.1.2.1.1.0\n"
    assert {:error, msg} = Bindocsis.parse(yaml, format: :docsis_configfile_yaml)
    assert msg =~ "COUNTER64"
  end

  test "bad OIDs, addresses and types are refused" do
    assert {:error, _} = SnmpVarbind.encode("sysDescr.0", "INTEGER", "1")
    assert {:error, _} = SnmpVarbind.encode("1.3.6.1.2.1.1.0", "IPADDRESS", "192.0.2")
    assert {:error, _} = SnmpVarbind.encode("1.3.6.1.2.1.1.0", "FLOAT", "1")
  end

  test "decode/1 refuses bytes that are not a variable binding" do
    assert {:error, _} = SnmpVarbind.decode(<<0x30, 0x03, 0x06, 0x01, 0x2B>>)
    assert {:error, _} = SnmpVarbind.decode(<<1, 2, 3>>)
  end
end
