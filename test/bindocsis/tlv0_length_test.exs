defmodule Bindocsis.TLV0LengthTest do
  use ExUnit.Case
  import ExUnit.CaptureLog

  describe "parse_tlv/2 TLV 0 length rule" do
    test "enforces 1-byte length for TLV type 0 with artificial binary" do
      # Test binary: TLV type 0, length 2, value bytes [6, 1]
      # According to TLV 0 length rule, this should be truncated to length 1 with value <<6>>
      binary = <<0, 2, 6, 1>>

      # Capture any log output during parsing
      log_output =
        capture_log(fn ->
          result = Bindocsis.parse_tlv(binary, [])

          # Should return one TLV with enforced length=1 and truncated value
          assert length(result) == 1
          [tlv] = result

          # Assert the TLV 0 length rule enforcement
          assert tlv.type == 0
          assert tlv.length == 1
          # First byte only, second byte (1) should be truncated
          assert tlv.value == <<6>>
        end)

      # Verify that error logging occurred for the length enforcement
      assert log_output =~ "Invalid TLV 0 length 2; forcing to 1"
    end

    test "allows valid TLV type 0 with length 1" do
      # Test with correct TLV 0: type 0, length 1, value [5]
      binary = <<0, 1, 5>>

      result = Bindocsis.parse_tlv(binary, [])

      assert length(result) == 1
      [tlv] = result

      assert tlv.type == 0
      assert tlv.length == 1
      assert tlv.value == <<5>>
    end
  end
end
