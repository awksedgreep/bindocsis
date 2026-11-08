defmodule MtaWireFormatTest do
  @moduledoc """
  DO NOT REMOVE: PacketCable MTA file wire format (PKT-SP-PROV1.5-C01-191120 §9.1).

  These fixtures are synthetic, but they mirror the layouts found in a
  production set of ~2,500 eMTA files (BASIC flow):

    254=0x01, TLV 11 x N, TLV 43, 254=0xFF                       (most files)
    254=0x01, TLV 43, TLV 11 x N, 254=0xFF, 6, 7, 0xFF + 0-3 x 0x00  (DOCSIS-tool built)

  Before this was fixed, 102 of those files failed to parse: they end in
  0xFF plus padding, which the parser read as a TLV header. The generator
  also appended an extra 0xFF to every file, and the MTA codec used DOCSIS
  0x81/0x82/0x84 extended lengths that PacketCable does not have.
  """
  use ExUnit.Case, async: true

  alias Bindocsis.Generators.MtaBinaryGenerator
  alias Bindocsis.Parsers.MtaBinaryParser

  @yaml """
  ---
  MtaConfigDelimiter:
  - 1
  - 255
  SnmpMibObject:
  - oid: 1.3.6.1.4.1.4491.2.2.1.1.1.7.0
    INTEGER: 1
  - oid: 1.3.6.1.2.1.2.2.1.7.9
    INTEGER: 1
  - oid: 1.3.6.1.4.1.99999.1.1.0
    STRING: user-0001
  - oid: 1.3.6.1.4.1.99999.1.2.0
    STRING: example-not-a-secret
  - oid: 1.3.6.1.4.1.99999.1.3.0
    IPADDRESS: 192.0.2.10
  VendorSpecific:
    id: '0x00000c'
    options:
    - 69
    - '0x0102030405'
  """

  defp body do
    {:ok, tlvs} = Bindocsis.parse(@yaml, format: :docsis_configfile_yaml)
    {:ok, bin} = Bindocsis.generate(tlvs, format: :mta)
    bin
  end

  defp mic(type), do: <<type, 16>> <> :binary.copy(<<type * 17>>, 16)

  test "a typical file round-trips byte for byte and ends at its end marker" do
    bin = body()
    assert <<254, 1, 1, _::binary>> = bin
    assert binary_part(bin, byte_size(bin) - 3, 3) == <<254, 1, 255>>

    {:ok, tlvs} = MtaBinaryParser.parse(bin)
    assert Enum.map(tlvs, & &1.type) == [254, 11, 11, 11, 11, 11, 43, 254]
    assert {:ok, ^bin} = MtaBinaryGenerator.generate(tlvs)
  end

  test "the DOCSIS trailer (MICs, 0xFF, 0-3 zero pad bytes) is kept and written back" do
    for pad <- 0..3 do
      trailer = <<0xFF>> <> :binary.copy(<<0>>, pad)
      file = body() <> mic(6) <> mic(7) <> trailer

      assert {:ok, %{tlvs: tlvs, trailer: ^trailer}} = MtaBinaryParser.parse_document(file)
      assert Enum.take(Enum.map(tlvs, & &1.type), -3) == [254, 6, 7]
      assert {:ok, ^file} = MtaBinaryGenerator.generate(tlvs, trailer: trailer)
    end
  end

  test "bytes after 0xFF that are not zero padding are an error, not dropped" do
    assert {:error, msg} = MtaBinaryParser.parse(body() <> <<0xFF, 0, 7>>)
    assert msg =~ "not all zero padding"
  end

  test "lengths are one plain byte: 0x81-0x84 are lengths, not extended markers" do
    for len <- [0x81, 0x82, 0x84, 254] do
      value = :binary.copy(<<0x41>>, len)
      file = <<254, 1, 1, 11, len>> <> value <> <<254, 1, 255>>
      assert {:ok, [_, %{type: 11, length: ^len}, _]} = MtaBinaryParser.parse(file)
      {:ok, tlvs} = MtaBinaryParser.parse(file)
      assert {:ok, ^file} = MtaBinaryGenerator.generate(tlvs)
    end
  end

  test "a long SNMP object becomes TLV 64 with a 2-byte length" do
    long = String.duplicate("x", 300)
    yaml = "---\nSnmpMibObject:\n- oid: 1.3.6.1.4.1.99999.1.9.0\n  STRING: #{long}\n"

    {:ok, [%{type: 64, length: len}] = tlvs} =
      Bindocsis.parse(yaml, format: :docsis_configfile_yaml)

    {:ok, bin} = Bindocsis.generate(tlvs, format: :mta)
    assert <<64, ^len::16, _::binary>> = bin
    assert {:ok, [%{type: 64, length: ^len}]} = MtaBinaryParser.parse(bin)
  end

  test "a TLV 11 over 254 bytes is refused rather than written with a bad length" do
    tlv = %{type: 11, length: 255, value: :binary.copy(<<0>>, 255)}
    assert {:error, msg} = MtaBinaryGenerator.generate([tlv])
    assert msg =~ "requires TLV 64"
  end

  test "Bindocsis.parse without a format reads an MTA file as MTA" do
    bin = body() <> mic(6) <> mic(7) <> <<0xFF, 0, 0>>
    {:ok, direct} = MtaBinaryParser.parse(bin)

    assert {:ok, auto} = Bindocsis.parse(bin, enhanced: false)
    assert Enum.map(auto, &{&1.type, &1.value}) == Enum.map(direct, &{&1.type, &1.value})
  end
end
