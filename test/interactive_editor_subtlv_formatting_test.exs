defmodule Bindocsis.InteractiveEditorSubTlvFormattingTest do
  use ExUnit.Case, async: true

  # format_subtlv_value is marked @doc false but is public for testing purposes
  # Helper to access the function for testing
  defp call_format_subtlv_value(subtlv) do
    Bindocsis.InteractiveEditor.format_subtlv_value(subtlv)
  end

  describe "format_subtlv_value/1 with Map formatted_value (SNMP MIB objects)" do
    test "handles map with atom keys" do
      subtlv = %{
        type: 64,
        value: <<0xFF, 0xFF, 0xFF, 0xFF>>,
        formatted_value: %{
          oid: "1.3.6.1.2.1.69.1.2.1.2.1",
          type: "Unknown Type 0x40",
          value: "Unknown Type 0x40: FFFFFFFF"
        }
      }

      result = call_format_subtlv_value(subtlv)

      assert result == "OID: 1.3.6.1.2.1.69.1.2.1.2.1, Type: Unknown Type 0x40, Value: FFFFFFFF"
    end

    test "handles map with string keys" do
      subtlv = %{
        type: 64,
        value: <<0xFF, 0xFF, 0xFF, 0xFF>>,
        formatted_value: %{
          "oid" => "1.3.6.1.2.1.69.1.2.1.2.1",
          "type" => "Unknown Type 0x40",
          "value" => "Unknown Type 0x40: FFFFFFFF"
        }
      }

      result = call_format_subtlv_value(subtlv)

      assert result == "OID: 1.3.6.1.2.1.69.1.2.1.2.1, Type: Unknown Type 0x40, Value: FFFFFFFF"
    end

    test "handles map with mixed atom and string keys" do
      # Create map dynamically to mix atom and string keys
      formatted_map =
        Map.new()
        |> Map.put(:oid, "1.3.6.1.2.1.69.1.2.1.2.1")
        |> Map.put("type", "Unknown Type 0x40")
        |> Map.put(:value, "FFFFFFFF")

      subtlv = %{
        type: 64,
        value: <<0xFF, 0xFF, 0xFF, 0xFF>>,
        formatted_value: formatted_map
      }

      result = call_format_subtlv_value(subtlv)

      assert result == "OID: 1.3.6.1.2.1.69.1.2.1.2.1, Type: Unknown Type 0x40, Value: FFFFFFFF"
    end

    test "strips redundant prefix from value string" do
      subtlv = %{
        type: 64,
        value: <<0x12, 0x34>>,
        formatted_value: %{
          oid: "1.3.6.1.4.1.123",
          type: "Unknown Type 0xAB",
          value: "Unknown Type 0xAB: 1234"
        }
      }

      result = call_format_subtlv_value(subtlv)

      assert result == "OID: 1.3.6.1.4.1.123, Type: Unknown Type 0xAB, Value: 1234"
    end

    test "handles integer value in map" do
      subtlv = %{
        type: 1,
        value: <<0x00, 0x00, 0x00, 0x42>>,
        formatted_value: %{
          oid: "1.3.6.1.2.1.1.1.0",
          type: "INTEGER",
          value: 66
        }
      }

      result = call_format_subtlv_value(subtlv)

      assert result == "OID: 1.3.6.1.2.1.1.1.0, Type: INTEGER, Value: 66"
    end

    test "falls back to hex when value is nil in map" do
      subtlv = %{
        type: 1,
        value: <<0x01, 0x0A, 0xFF>>,
        formatted_value: %{
          oid: "1.3.6.1.2.1.1.1.0",
          type: "Unknown",
          value: nil
        }
      }

      result = call_format_subtlv_value(subtlv)

      assert result == "OID: 1.3.6.1.2.1.1.1.0, Type: Unknown, Value: 01 0A FF"
    end

    test "falls back to hex when value is unexpected structure (nested map)" do
      subtlv = %{
        type: 1,
        value: <<0xAB, 0xCD>>,
        formatted_value: %{
          oid: "1.3.6.1.2.1.1.1.0",
          type: "Complex",
          value: %{nested: "structure"}
        }
      }

      result = call_format_subtlv_value(subtlv)

      assert result == "OID: 1.3.6.1.2.1.1.1.0, Type: Complex, Value: AB CD"
    end

    test "falls back to hex when value is unexpected structure (list)" do
      subtlv = %{
        type: 1,
        value: <<0x12, 0x34, 0x56>>,
        formatted_value: %{
          oid: "1.3.6.1.2.1.1.1.0",
          type: "List",
          value: [1, 2, 3]
        }
      }

      result = call_format_subtlv_value(subtlv)

      assert result == "OID: 1.3.6.1.2.1.1.1.0, Type: List, Value: 12 34 56"
    end
  end

  describe "format_subtlv_value/1 with string formatted_value" do
    test "returns non-empty string as-is" do
      subtlv = %{
        type: 1,
        value: <<0x01>>,
        formatted_value: "Enabled"
      }

      result = call_format_subtlv_value(subtlv)

      assert result == "Enabled"
    end

    test "returns complex string unchanged" do
      subtlv = %{
        type: 2,
        value: <<0x12, 0x34>>,
        formatted_value: "Service Flow #1234"
      }

      result = call_format_subtlv_value(subtlv)

      assert result == "Service Flow #1234"
    end
  end

  describe "format_subtlv_value/1 with nil or empty formatted_value" do
    test "falls back to uppercase spaced hex when formatted_value is nil" do
      subtlv = %{
        type: 1,
        value: <<0x01, 0x0A, 0xFF>>,
        formatted_value: nil
      }

      result = call_format_subtlv_value(subtlv)

      assert result == "01 0A FF"
    end

    test "falls back to uppercase spaced hex when formatted_value is empty string" do
      subtlv = %{
        type: 1,
        value: <<0xAB, 0xCD, 0xEF>>,
        formatted_value: ""
      }

      result = call_format_subtlv_value(subtlv)

      assert result == "AB CD EF"
    end

    test "handles single byte correctly" do
      subtlv = %{
        type: 1,
        value: <<0x05>>,
        formatted_value: nil
      }

      result = call_format_subtlv_value(subtlv)

      assert result == "05"
    end

    test "handles zero byte correctly" do
      subtlv = %{
        type: 1,
        value: <<0x00>>,
        formatted_value: nil
      }

      result = call_format_subtlv_value(subtlv)

      assert result == "00"
    end

    test "handles multi-byte values with leading zeros" do
      subtlv = %{
        type: 1,
        value: <<0x00, 0x0F, 0xFF>>,
        formatted_value: nil
      }

      result = call_format_subtlv_value(subtlv)

      assert result == "00 0F FF"
    end
  end

  describe "format_subtlv_value/1 edge cases" do
    test "handles empty binary value with nil formatted_value" do
      subtlv = %{
        type: 1,
        value: <<>>,
        formatted_value: nil
      }

      result = call_format_subtlv_value(subtlv)

      assert result == ""
    end

    test "handles map with only some keys present" do
      subtlv = %{
        type: 64,
        value: <<0x12, 0x34>>,
        formatted_value: %{
          oid: "1.3.6.1.2.1.1.1.0"
          # Missing type and value
        }
      }

      result = call_format_subtlv_value(subtlv)

      # Should handle nil gracefully
      assert String.contains?(result, "OID: 1.3.6.1.2.1.1.1.0")
    end
  end

  describe "binary_to_spaced_hex/1 helper (via format_subtlv_value)" do
    test "converts single byte to uppercase hex" do
      subtlv = %{type: 1, value: <<0xFF>>, formatted_value: nil}
      assert call_format_subtlv_value(subtlv) == "FF"
    end

    test "converts multiple bytes with space separation" do
      subtlv = %{type: 1, value: <<0x01, 0x02, 0x03>>, formatted_value: nil}
      assert call_format_subtlv_value(subtlv) == "01 02 03"
    end

    test "pads single-digit hex values with leading zero" do
      subtlv = %{type: 1, value: <<0x0A, 0x0B, 0x0C>>, formatted_value: nil}
      assert call_format_subtlv_value(subtlv) == "0A 0B 0C"
    end

    test "converts to uppercase hex" do
      subtlv = %{type: 1, value: <<0xAB, 0xCD, 0xEF>>, formatted_value: nil}
      result = call_format_subtlv_value(subtlv)
      assert result == String.upcase(result)
      assert result == "AB CD EF"
    end
  end
end
