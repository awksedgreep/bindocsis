defmodule Bindocsis.ParserTailTest do
  use ExUnit.Case, async: true

  @moduledoc "Truncated / trailing-garbage handling in the binary parser (issue #5)."

  test "a lone trailing byte after valid TLVs is an error, not a shorter result" do
    assert {:error, msg} = Bindocsis.parse(<<3, 1, 1, 10>>, format: :binary)
    assert msg =~ "trailing byte 0x0A"
    assert {:error, _} = Bindocsis.parse_tlv(<<10>>, [])
  end

  test "declared length beyond the end of the data is an error" do
    assert {:error, msg} = Bindocsis.parse(<<3, 1, 1, 18, 5, 1, 2>>, format: :binary)
    assert msg =~ "insufficient data"
  end

  test "non-zero bytes after the 0xFF End-of-Data marker are an error" do
    assert {:error, msg} = Bindocsis.parse(<<3, 1, 1, 0xFF, 0xDE, 0xAD>>, format: :binary)
    assert msg =~ "after the 0xFF"
    assert {:error, _} = Bindocsis.parse_tlv(<<3, 1, 1, 255, 10, 20>>, [])
  end

  test "zero padding after the 0xFF marker is still accepted" do
    assert {:ok, [%{type: 3}]} = Bindocsis.parse(<<3, 1, 1, 0xFF, 0, 0, 0>>, format: :binary)
    assert [%{type: 3}] = Bindocsis.parse_tlv(<<3, 1, 1, 255, 0, 0, 0>>, [])
  end

  test "the format validator result is honoured" do
    # Two bytes: the validator rejects before parse_tlv/2 ever runs, and the
    # MTA fallback cannot parse it either.
    assert {:error, msg} = Bindocsis.parse(<<1, 2>>, format: :binary)
    assert msg =~ "Not a valid DOCSIS TLV file"
  end

  test "a truncated extended length is an error" do
    assert {:error, msg} = Bindocsis.parse(<<3, 1, 1, 43, 0x82, 0x01>>, format: :binary)
    assert msg =~ "0x82"
  end
end
