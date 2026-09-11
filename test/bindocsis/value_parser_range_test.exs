defmodule Bindocsis.ValueParserRangeTest do
  use ExUnit.Case, async: true

  alias Bindocsis.ValueParser

  @moduledoc "Out-of-range integers must error, never widen or truncate (issue #8)."

  test "uint8 integers above 255 are rejected instead of widened" do
    assert {:error, msg} = ValueParser.parse_value(:uint8, 300, [])
    assert msg =~ "out of range for uint8"
    assert {:error, _} = ValueParser.parse_value(:uint8, 70_000, [])
    assert {:error, _} = ValueParser.parse_value(:uint8, "300", [])
    assert {:ok, <<255>>} = ValueParser.parse_value(:uint8, 255, [])
    assert {:ok, <<255>>} = ValueParser.parse_value(:uint8, "255", [])
  end

  test "uint16 / uint32 integers out of range are rejected with a clear message" do
    assert {:error, msg} = ValueParser.parse_value(:uint16, 70_000, [])
    assert msg =~ "out of range for uint16"
    assert {:error, msg} = ValueParser.parse_value(:uint32, 5_000_000_000, [])
    assert msg =~ "out of range for uint32"
  end

  test "uint32 string input out of range is rejected instead of truncated" do
    assert {:ok, <<0xFF, 0xFF, 0xFF, 0xFF>>} = ValueParser.parse_value(:uint32, "4294967295", [])
    # 10 decimal digits that also read as hex: never truncated to the first 4 bytes
    assert {:error, _} = ValueParser.parse_value(:uint32, "9999999999", [])
    assert {:error, _} = ValueParser.parse_value(:uint32, "1234567890AB", [])
  end
end
