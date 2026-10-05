defmodule Bindocsis.Parsers.MtaBinaryParserTest do
  use ExUnit.Case, async: true

  alias Bindocsis.Parsers.MtaBinaryParser

  @moduledoc "MTA parser must never emit a TLV that consumed no length byte (issue #9)."

  test "an over-long 0x84 length is reported, not repaired by inventing a zero-length TLV" do
    # 0x43 followed by 0x84: the old heuristic emitted {67, 0, <<>>} (1 wire
    # byte, re-encodes as 2) and restarted at 0x84.
    ambiguous = <<0x43, 0x84, 0x08, 0x03, 0x00, 0x15, 1, 2, 3, 4, 5>>

    assert {:error, msg} = MtaBinaryParser.parse(ambiguous)
    assert msg =~ "TLV 67"
    assert msg =~ "Line Package"
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

  test "extended lengths decode with the shared codec" do
    value = :binary.copy(<<0xAA>>, 300)
    bin = <<69, 0x82, 300::16>> <> value
    assert {:ok, [%{type: 69, length: 300, value: ^value}]} = MtaBinaryParser.parse(bin)

    plain = <<69, 0x83>> <> :binary.copy(<<0xBB>>, 0x83)
    assert {:ok, [%{type: 69, length: 0x83}]} = MtaBinaryParser.parse(plain)
  end

  test "every parsed TLV accounts for its own bytes" do
    {:ok, parsed} = MtaBinaryParser.parse(<<3, 1, 1, 69, 2, 0x41, 0x42, 84, 0>>)

    total =
      Enum.reduce(parsed, 0, fn t, acc -> acc + Bindocsis.TlvLength.encoded_size(t.length) end)

    assert total == 9
  end
end
