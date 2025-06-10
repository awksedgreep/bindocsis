defmodule Bindocsis.Parsers.JsonParserTest do
  use ExUnit.Case, async: true
  alias Bindocsis.Parsers.JsonParser
  
  # Note: Doctests disabled due to file dependencies

  describe "parse/1 with valid JSON" do
    test "parses simple TLV with integer value" do
      json = ~s({"tlvs": [{"type": 3, "value": 1}]})
      
      assert {:ok, [tlv]} = JsonParser.parse(json)
      assert tlv.type == 3
      assert tlv.length == 1
      assert tlv.value == <<1>>
    end

    test "parses multiple TLVs" do
      json = ~s({"tlvs": [{"type": 3, "value": 1}, {"type": 21, "value": 5}]})
      
      assert {:ok, [tlv1, tlv2]} = JsonParser.parse(json)
      assert tlv1.type == 3
      assert tlv1.value == <<1>>
      assert tlv2.type == 21
      assert tlv2.value == <<5>>
    end

    test "parses TLV with hex string value" do
      json = ~s({"tlvs": [{"type": 6, "value": "AA BB CC DD"}]})
      
      assert {:ok, [tlv]} = JsonParser.parse(json)
      assert tlv.type == 6
      assert tlv.length == 4
      assert tlv.value == <<170, 187, 204, 221>>
    end

    test "parses TLV with hex string without spaces" do
      json = ~s({"tlvs": [{"type": 6, "value": "AABBCCDD"}]})
      
      assert {:ok, [tlv]} = JsonParser.parse(json)
      assert tlv.type == 6
      assert tlv.length == 4
      assert tlv.value == <<170, 187, 204, 221>>
    end

    test "parses TLV with byte array value" do
      json = ~s({"tlvs": [{"type": 6, "value": [170, 187, 204, 221]}]})
      
      assert {:ok, [tlv]} = JsonParser.parse(json)
      assert tlv.type == 6
      assert tlv.length == 4
      assert tlv.value == <<170, 187, 204, 221>>
    end

    test "parses TLV with string value" do
      json = ~s({"tlvs": [{"type": 13, "value": "TestProvider"}]})
      
      assert {:ok, [tlv]} = JsonParser.parse(json)
      assert tlv.type == 13
      assert tlv.length == 12
      assert tlv.value == "TestProvider"
    end

    test "parses TLV with float value" do
      json = ~s({"tlvs": [{"type": 50, "value": 3.14159}]})
      
      assert {:ok, [tlv]} = JsonParser.parse(json)
      assert tlv.type == 50
      assert tlv.length == 4
      assert tlv.value == <<3.14159::float-32>>
    end

    test "parses TLV with subtlvs" do
      json = ~s({
        "tlvs": [{
          "type": 4,
          "subtlvs": [
            {"type": 1, "value": 1},
            {"type": 2, "value": 1000000}
          ]
        }]
      })
      
      assert {:ok, [tlv]} = JsonParser.parse(json)
      assert tlv.type == 4
      assert tlv.length > 0
      assert is_binary(tlv.value)
      
      # The value should contain encoded subtlvs
      # Type 1, Length 1, Value 1 = <<1, 1, 1>>
      # Type 2, Length 4, Value 1000000 = <<2, 4, 0, 15, 66, 64>>
      expected_subtlvs = <<1, 1, 1, 2, 4, 0, 15, 66, 64>>
      assert tlv.value == expected_subtlvs
    end

    test "parses TLV with nested subtlvs" do
      json = ~s({
        "tlvs": [{
          "type": 24,
          "subtlvs": [
            {"type": 1, "value": 1},
            {
              "type": 22,
              "subtlvs": [
                {"type": 1, "value": 100}
              ]
            }
          ]
        }]
      })
      
      assert {:ok, [tlv]} = JsonParser.parse(json)
      assert tlv.type == 24
      assert is_binary(tlv.value)
    end

    test "parses full format with docsis_version and metadata" do
      json = ~s({
        "docsis_version": "3.1",
        "tlvs": [{
          "type": 3,
          "name": "Web Access Control",
          "length": 1,
          "value": 1,
          "description": "Enabled"
        }]
      })
      
      assert {:ok, [tlv]} = JsonParser.parse(json)
      assert tlv.type == 3
      assert tlv.length == 1
      assert tlv.value == <<1>>
    end

    test "handles empty TLV array" do
      json = ~s({"tlvs": []})
      
      assert {:ok, []} = JsonParser.parse(json)
    end

    test "handles zero-length values" do
      json = ~s({"tlvs": [{"type": 254, "value": ""}]})
      
      assert {:ok, [tlv]} = JsonParser.parse(json)
      assert tlv.type == 254
      assert tlv.length == 0
      assert tlv.value == <<>>
    end
  end

  describe "parse/1 with different integer sizes" do
    test "handles 8-bit integers" do
      json = ~s({"tlvs": [{"type": 3, "value": 255}]})
      
      assert {:ok, [tlv]} = JsonParser.parse(json)
      assert tlv.value == <<255>>
      assert tlv.length == 1
    end

    test "handles 16-bit integers" do
      json = ~s({"tlvs": [{"type": 3, "value": 65535}]})
      
      assert {:ok, [tlv]} = JsonParser.parse(json)
      assert tlv.value == <<255, 255>>
      assert tlv.length == 2
    end

    test "handles 32-bit integers" do
      json = ~s({"tlvs": [{"type": 3, "value": 4294967295}]})
      
      assert {:ok, [tlv]} = JsonParser.parse(json)
      assert tlv.value == <<255, 255, 255, 255>>
      assert tlv.length == 4
    end

    test "handles 64-bit integers" do
      json = ~s({"tlvs": [{"type": 3, "value": 18446744073709551615}]})
      
      assert {:ok, [tlv]} = JsonParser.parse(json)
      assert tlv.length == 8
      assert is_binary(tlv.value)
    end
  end

  describe "parse/1 error handling" do
    test "returns error for invalid JSON syntax" do
      json = ~s({"tlvs": [{"type": 3, "value": 1})  # Missing closing brace
      
      assert {:error, error_msg} = JsonParser.parse(json)
      assert error_msg =~ "JSON parsing error"
    end

    test "returns error for missing tlvs field" do
      json = ~s({"docsis_version": "3.1"})
      
      assert {:error, error_msg} = JsonParser.parse(json)
      assert error_msg == "Missing 'tlvs' array in JSON"
    end

    test "returns error for non-array tlvs field" do
      json = ~s({"tlvs": "not an array"})
      
      assert {:error, error_msg} = JsonParser.parse(json)
      assert error_msg == "Missing 'tlvs' array in JSON"
    end

    test "returns error for TLV without type field" do
      json = ~s({"tlvs": [{"value": 1}]})
      
      assert {:error, error_msg} = JsonParser.parse(json)
      assert error_msg =~ "TLV conversion error"
    end

    test "returns error for invalid TLV type" do
      json = ~s({"tlvs": [{"type": "invalid", "value": 1}]})
      
      assert {:error, error_msg} = JsonParser.parse(json)
      assert error_msg =~ "TLV conversion error"
    end

    test "treats invalid hex string as regular string" do
      json = ~s({"tlvs": [{"type": 6, "value": "INVALID_HEX"}]})
      
      assert {:ok, [tlv]} = JsonParser.parse(json)
      assert tlv.type == 6
      assert tlv.value == "INVALID_HEX"
      assert tlv.length == 11
    end

    test "handles hex string with odd length gracefully" do
      json = ~s({"tlvs": [{"type": 6, "value": "AAB"}]})
      
      # The parser should handle this gracefully by treating it as a string
      assert {:ok, [tlv]} = JsonParser.parse(json)
      assert tlv.type == 6
      assert tlv.value == "AAB"
    end

    test "returns error for invalid byte array values" do
      json = ~s({"tlvs": [{"type": 6, "value": [256, 300]}]})
      
      assert {:error, error_msg} = JsonParser.parse(json)
      assert error_msg =~ "TLV conversion error"
    end

    test "handles null value as empty value" do
      json = ~s({"tlvs": [{"type": 6, "value": null}]})
      
      assert {:ok, [tlv]} = JsonParser.parse(json)
      assert tlv.type == 6
      assert tlv.value == ""
      assert tlv.length == 0
    end
  end

  describe "parse_file/1" do
    setup do
      # Create temporary test files
      valid_json = ~s({"tlvs": [{"type": 3, "value": 1}]})
      invalid_json = ~s({"tlvs": [{"type": 3, "value": 1})
      
      valid_file = Path.join(System.tmp_dir!(), "valid_test.json")
      invalid_file = Path.join(System.tmp_dir!(), "invalid_test.json")
      nonexistent_file = Path.join(System.tmp_dir!(), "nonexistent.json")
      
      File.write!(valid_file, valid_json)
      File.write!(invalid_file, invalid_json)
      
      on_exit(fn ->
        File.rm(valid_file)
        File.rm(invalid_file)
      end)
      
      %{
        valid_file: valid_file,
        invalid_file: invalid_file,
        nonexistent_file: nonexistent_file
      }
    end

    test "parses valid JSON file", %{valid_file: file} do
      assert {:ok, [tlv]} = JsonParser.parse_file(file)
      assert tlv.type == 3
      assert tlv.value == <<1>>
    end

    test "returns error for invalid JSON file", %{invalid_file: file} do
      assert {:error, error_msg} = JsonParser.parse_file(file)
      assert error_msg =~ "JSON parsing error"
    end

    test "returns error for nonexistent file", %{nonexistent_file: file} do
      assert {:error, error_msg} = JsonParser.parse_file(file)
      assert error_msg =~ "File read error"
    end
  end

  describe "validate_structure/1" do
    test "validates correct structure" do
      data = %{"tlvs" => [%{"type" => 3, "value" => 1}]}
      assert :ok = JsonParser.validate_structure(data)
    end

    test "rejects structure without tlvs" do
      data = %{"docsis_version" => "3.1"}
      assert {:error, _} = JsonParser.validate_structure(data)
    end

    test "rejects structure with non-array tlvs" do
      data = %{"tlvs" => "not an array"}
      assert {:error, _} = JsonParser.validate_structure(data)
    end

    test "rejects TLV without type" do
      data = %{"tlvs" => [%{"value" => 1}]}
      assert {:error, _} = JsonParser.validate_structure(data)
    end

    test "rejects TLV with invalid type" do
      data = %{"tlvs" => [%{"type" => 256, "value" => 1}]}
      assert {:error, _} = JsonParser.validate_structure(data)
    end
  end

  describe "complex real-world scenarios" do
    test "parses complete DOCSIS configuration" do
      json = ~s({
        "docsis_version": "3.1",
        "tlvs": [
          {"type": 3, "value": 1},
          {
            "type": 4,
            "subtlvs": [
              {"type": 1, "value": 1},
              {"type": 2, "value": 1000000},
              {"type": 3, "value": 200000},
              {"type": 4, "value": 1}
            ]
          },
          {
            "type": 17,
            "subtlvs": [
              {"type": 1, "value": 1},
              {"type": 6, "value": 0},
              {"type": 7, "value": 1000000}
            ]
          },
          {"type": 21, "value": 5},
          {"type": 6, "value": "AA BB CC DD EE FF 11 22 33 44 55 66 77 88 99 00"},
          {"type": 7, "value": "FF EE DD CC BB AA 00 99 88 77 66 55 44 33 22 11"}
        ]
      })
      
      assert {:ok, tlvs} = JsonParser.parse(json)
      assert length(tlvs) == 6
      
      # Verify each TLV type
      types = Enum.map(tlvs, & &1.type)
      assert types == [3, 4, 17, 21, 6, 7]
      
      # Verify compound TLVs have binary values (encoded subtlvs)
      compound_tlv = Enum.find(tlvs, &(&1.type == 4))
      assert is_binary(compound_tlv.value)
      assert compound_tlv.length > 0
    end

    test "handles mixed value types in single configuration" do
      json = ~s({
        "tlvs": [
          {"type": 3, "value": 1},
          {"type": 13, "value": "ServiceProvider"},
          {"type": 6, "value": "AA BB CC DD"},
          {"type": 21, "value": [1, 2, 3, 4]},
          {"type": 50, "value": 3.14159}
        ]
      })
      
      assert {:ok, tlvs} = JsonParser.parse(json)
      assert length(tlvs) == 5
      
      # Verify different value types are correctly converted
      [int_tlv, string_tlv, hex_tlv, array_tlv, float_tlv] = tlvs
      
      assert int_tlv.value == <<1>>
      assert string_tlv.value == "ServiceProvider"
      assert hex_tlv.value == <<170, 187, 204, 221>>
      assert array_tlv.value == <<1, 2, 3, 4>>
      assert float_tlv.value == <<3.14159::float-32>>
    end
  end

  describe "performance and edge cases" do
    @tag :performance
    test "handles large TLV arrays efficiently" do
      # Generate 1000 TLVs
      tlvs = for i <- 1..1000 do
        %{"type" => rem(i, 255) + 1, "value" => i}
      end
      
      json = JSON.encode!(%{"tlvs" => tlvs})
      
      {time, {:ok, parsed_tlvs}} = :timer.tc(fn -> JsonParser.parse(json) end)
      
      assert length(parsed_tlvs) == 1000
      # Should parse within reasonable time (less than 1 second)
      assert time < 1_000_000
    end

    @tag :performance
    test "handles very large values" do
      large_hex = String.duplicate("AA", 10000)
      json = ~s({"tlvs": [{"type": 6, "value": "#{large_hex}"}]})
      
      assert {:ok, [tlv]} = JsonParser.parse(json)
      assert tlv.type == 6
      assert byte_size(tlv.value) == 10000
    end

    @tag :performance
    test "handles deeply nested subtlvs" do
      json = ~s({
        "tlvs": [{
          "type": 24,
          "subtlvs": [{
            "type": 22,
            "subtlvs": [{
              "type": 43,
              "subtlvs": [{
                "type": 1,
                "value": 42
              }]
            }]
          }]
        }]
      })
      
      assert {:ok, [tlv]} = JsonParser.parse(json)
      assert tlv.type == 24
      assert is_binary(tlv.value)
    end
  end
end