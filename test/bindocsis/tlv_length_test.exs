defmodule Bindocsis.TlvLengthTest do
  use ExUnit.Case, async: true

  alias Bindocsis.TlvLength

  @samples [
    0,
    1,
    127,
    128,
    0x81,
    0x82,
    0x83,
    0x84,
    0x85,
    200,
    254,
    255,
    256,
    300,
    0xFFFF,
    0x10000,
    70_000
  ]

  test "encode/decode round-trips every length, including the marker values" do
    for len <- @samples do
      encoded = TlvLength.encode(len)
      assert {:ok, ^len, <<"tail">>} = TlvLength.decode(encoded <> "tail"), "length #{len}"
      assert byte_size(encoded) == TlvLength.field_size(len), "field_size for #{len}"
    end
  end

  test "exhaustive round-trip for every single/two/three-byte length" do
    for len <- 0..0x10000 do
      assert {:ok, ^len, <<>>} = TlvLength.decode(TlvLength.encode(len))
    end
  end

  test "0x81/0x82/0x84 as plain lengths are escaped with an 0x81 prefix" do
    assert TlvLength.encode(0x81) == <<0x81, 0x81>>
    assert TlvLength.encode(0x82) == <<0x81, 0x82>>
    assert TlvLength.encode(0x84) == <<0x81, 0x84>>
    assert TlvLength.field_size(0x82) == 2
  end

  test "other bytes >= 0x80 are plain one-byte lengths in both directions" do
    assert TlvLength.encode(0x80) == <<0x80>>
    assert TlvLength.encode(0x83) == <<0x83>>
    assert TlvLength.encode(0xFE) == <<0xFE>>
    assert {:ok, 0x83, <<>>} = TlvLength.decode(<<0x83>>)
    assert {:ok, 0xFE, <<1>>} = TlvLength.decode(<<0xFE, 1>>)
  end

  test "multi-byte encodings" do
    assert TlvLength.encode(256) == <<0x82, 1, 0>>
    assert TlvLength.encode(0x10000) == <<0x84, 0, 1, 0, 0>>
    assert TlvLength.field_size(256) == 3
    assert TlvLength.field_size(0x10000) == 5
    assert TlvLength.encoded_size(300) == 1 + 3 + 300
  end

  test "truncated markers and missing bytes are errors" do
    assert {:error, msg} = TlvLength.decode(<<0x82, 1>>)
    assert msg =~ "0x82"
    assert {:error, _} = TlvLength.decode(<<0x84, 0, 0>>)
    assert {:error, _} = TlvLength.decode(<<>>)
  end

  test "out-of-range lengths raise" do
    assert_raise ArgumentError, fn -> TlvLength.encode(0x1_0000_0000) end
    assert_raise ArgumentError, fn -> TlvLength.encode(-1) end
  end

  describe "all codec paths agree (issues #6, #7)" do
    test "binary generator output parses back for every length class" do
      for len <- [5, 127, 128, 0x81, 0x84, 200, 255, 256, 70_000] do
        value = :binary.copy(<<0xAB>>, len)
        tlv = %{type: 43, length: len, value: value}

        {:ok, bin} = Bindocsis.Generators.BinaryGenerator.generate([tlv], terminate: false)
        assert bin == <<43>> <> TlvLength.encode(len) <> value

        assert {:ok, [%{type: 43, length: ^len, value: ^value}]} =
                 Bindocsis.parse(bin, format: :binary, enhanced: false)
      end
    end

    test "MTA generator uses the same encoding as the DOCSIS generator" do
      for len <- [200, 0x81, 300] do
        tlv = %{type: 69, length: len, value: :binary.copy(<<0x41>>, len)}
        {:ok, docsis} = Bindocsis.generate([tlv], format: :binary, terminate: false)
        {:ok, mta} = Bindocsis.generate([tlv], format: :mta, terminate: false)
        assert docsis == mta
      end
    end

    test "enricher re-serialises sub-TLVs with the shared codec" do
      # TLV 43 (Vendor Specific) with a 200-byte sub-TLV: plain length byte
      sub_value = :binary.copy(<<0x5A>>, 200)
      compound_value = <<8, 3, 0, 0x10, 0x95>> <> <<9>> <> TlvLength.encode(200) <> sub_value
      bin = <<43>> <> TlvLength.encode(byte_size(compound_value)) <> compound_value

      {:ok, [enriched]} = Bindocsis.parse(bin, format: :binary, enhanced: true)
      assert [_, %{type: 9, length: 200}] = enriched.subtlvs

      [raw] = Bindocsis.TlvEnricher.unenrich_tlvs([enriched])
      assert raw.value == compound_value
    end
  end
end
