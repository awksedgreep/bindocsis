defmodule Bindocsis.Parsers.MtaBinaryParserTest do
  use ExUnit.Case, async: true

  alias Bindocsis.Parsers.MtaBinaryParser

  @moduledoc "MTA parser must never emit a TLV that consumed no length byte (issue #9)."

  test "an over-long length is reported, not repaired by inventing a zero-length TLV" do
    # 0x43 followed by 0x84: the old heuristic emitted {67, 0, <<>>} (1 wire
    # byte, re-encodes as 2) and restarted at 0x84. 0x84 is a plain length
    # (132) in an MTA file, which overruns this input.
    ambiguous = <<0x43, 0x84, 0x08, 0x03, 0x00, 0x15, 1, 2, 3, 4, 5>>

    assert {:error, msg} = MtaBinaryParser.parse(ambiguous)
    assert msg =~ "TLV 67"
    assert msg =~ "need 132 bytes"
  end

  test "an explicit zero-length TLV followed by TLV 84 parses and round-trips byte-exactly" do
    tlvs = [
      %{type: 67, length: 0, value: <<>>},
      %{type: 84, length: 8, value: <<1, 2, 3, 4, 5, 6, 7, 8>>}
    ]

    {:ok, bin} = Bindocsis.generate(tlvs, format: :mta, terminate: false)
    assert bin == <<67, 0, 84, 8, 1, 2, 3, 4, 5, 6, 7, 8>>

    {:ok, parsed} = MtaBinaryParser.parse(bin)
    assert Enum.map(parsed, &Map.take(&1, [:type, :length, :value])) == tlvs

    {:ok, regenerated} = Bindocsis.generate(parsed, format: :mta, terminate: false)
    assert regenerated == bin
  end

  test "TLV 64 has a 2-byte length; every 0x8X length byte is plain (PROV1.5 §9.1)" do
    value = :binary.copy(<<0xAA>>, 300)

    assert {:ok, [%{type: 64, length: 300, value: ^value}]} =
             MtaBinaryParser.parse(<<64, 300::16>> <> value)

    for len <- [0x81, 0x82, 0x83, 0x84] do
      plain = <<11, len>> <> :binary.copy(<<0xBB>>, len)
      assert {:ok, [%{type: 11, length: ^len}]} = MtaBinaryParser.parse(plain)
    end
  end

  test "every parsed TLV accounts for its own bytes" do
    {:ok, parsed} = MtaBinaryParser.parse(<<3, 1, 1, 69, 2, 0x41, 0x42, 84, 0>>)

    total =
      Enum.reduce(parsed, 0, fn t, acc ->
        acc + 1 + Bindocsis.MtaTlvLength.field_size(t.type) + t.length
      end)

    assert total == 9
  end
end
