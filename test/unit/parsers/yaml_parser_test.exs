defmodule Bindocsis.Parsers.YamlParserTest do
  use ExUnit.Case, async: true
  alias Bindocsis.Parsers.YamlParser
  
  doctest YamlParser

  describe "parse/1 with valid YAML" do
    test "parses simple TLV with integer value" do
      yaml = """
      tlvs:
        - type: 3
          value: 1
      """
      
      assert {:ok, [tlv]} = YamlParser.parse(yaml)
      assert tlv.type == 3
      assert tlv.length == 1
      assert tlv.value == <<1>>
    end

    test "parses multiple TLVs" do
      yaml = """
      tlvs:
        - type: 3
          value: 1
        - type: 21
          value: 5
      """
      
      assert {:ok, [tlv1, tlv2]} = YamlParser.parse(yaml)
      assert tlv1.type == 3
      assert tlv1.value == <<1>>
      assert tlv2.type == 21
      assert tlv2.value == <<5>>
    end

    test "parses TLV with hex string value with spaces" do
      yaml = """
      tlvs:
        - type: 6
          value: "AA BB CC DD"
      """
      
      assert {:ok, [tlv]} = YamlParser.parse(yaml)
      assert tlv.type == 6
      assert tlv.length == 4
      assert tlv.value == <<170, 187, 204, 221>>
    end

    test "parses TLV with hex string value with colons" do
      yaml = """
      tlvs:
        - type: 6
          value: "AA:BB:CC:DD"
      """
      
      assert {:ok, [tlv]} = YamlParser.parse(yaml)
      assert tlv.type == 6
      assert tlv.length == 4
      assert tlv.value == <<170, 187, 204, 221>>
    end

    test "parses TLV with hex string without separators" do
      yaml = """
      tlvs:
        - type: 6
          value: "AABBCCDD"
      """
      
      assert {:ok, [tlv]} = YamlParser.parse(yaml)
      assert tlv.type == 6
      assert tlv.length == 4
      assert tlv.value == <<170, 187, 204, 221>>
    end

    test "parses TLV with byte array value" do
      yaml = """
      tlvs:
        - type: 6
          value: [170, 187, 204, 221]
      """
      
      assert {:ok, [tlv]} = YamlParser.parse(yaml)
      assert tlv.type == 6
      assert tlv.length == 4
      assert tlv.value == <<170, 187, 204, 221>>
    end

    test "parses TLV with string value" do
      yaml = """
      tlvs:
        - type: 13
          value: "TestProvider"
      """
      
      assert {:ok, [tlv]} = YamlParser.parse(yaml)
      assert tlv.type == 13
      assert tlv.length == 12
      assert tlv.value == "TestProvider"
    end

    test "parses TLV with unquoted string value" do
      yaml = """
      tlvs:
        - type: 13
          value: TestProvider
      """
      
      assert {:ok, [tlv]} = YamlParser.parse(yaml)
      assert tlv.type == 13
      assert tlv.length == 12
      assert tlv.value == "TestProvider"
    end

    test "parses TLV with float value" do
      yaml = """
      tlvs:
        - type: 50
          value: 3.14159
      """
      
      assert {:ok, [tlv]} = YamlParser.parse(yaml)
      assert tlv.type == 50
      assert tlv.length == 4
      assert tlv.value == <<3.14159::float-32>>
    end

    test "parses TLV with subtlvs" do
      yaml = """
      tlvs:
        - type: 4
          subtlvs:
            - type: 1
              value: 1
            - type: 2
              value: 1000000
      """
      
      assert {:ok, [tlv]} = YamlParser.parse(yaml)
      assert tlv.type == 4
      assert tlv.length > 0
      assert is_binary(tlv.value)
      
      # The value should contain encoded subtlvs
      expected_subtlvs = <<1, 1, 1, 2, 4, 0, 15, 66, 64>>
      assert tlv.value == expected_subtlvs
    end

    test "parses TLV with nested subtlvs" do
      yaml = """
      tlvs:
        - type: 24
          subtlvs:
            - type: 1
              value: 1
            - type: 22
              subtlvs:
                - type: 1
                  value: 100
      """
      
      assert {:ok, [tlv]} = YamlParser.parse(yaml)
      assert tlv.type == 24
      assert is_binary(tlv.value)
    end

    test "parses full format with docsis_version and metadata" do
      yaml = """
      docsis_version: "3.1"
      tlvs:
        - type: 3
          name: "Network Access Control"
          length: 1
          value: 1
          description: "Enabled"
      """
      
      assert {:ok, [tlv]} = YamlParser.parse(yaml)
      assert tlv.type == 3
      assert tlv.length == 1
      assert tlv.value == <<1>>
    end

    test "handles empty TLV array" do
      yaml = """
      tlvs: []
      """
      
      assert {:ok, []} = YamlParser.parse(yaml)
    end

    test "handles zero-length values" do
      yaml = """
      tlvs:
        - type: 254
          value: ""
      """
      
      assert {:ok, [tlv]} = YamlParser.parse(yaml)
      assert tlv.type == 254
      assert tlv.length == 0
      assert tlv.value == <<>>
    end

    test "parses YAML with inline array syntax" do
      yaml = """
      tlvs:
        - {type: 3, value: 1}
        - {type: 21, value: 5}
      """
      
      assert {:ok, [tlv1, tlv2]} = YamlParser.parse(yaml)
      assert tlv1.type == 3
      assert tlv2.type == 21
    end

    test "parses YAML with flow sequence for values" do
      yaml = """
      tlvs:
        - type: 6
          value: [0xAA, 0xBB, 0xCC, 0xDD]
      """
      
      assert {:ok, [tlv]} = YamlParser.parse(yaml)
      assert tlv.type == 6
      assert tlv.value == <<170, 187, 204, 221>>
    end
  end

  describe "parse/1 with different integer sizes" do
    test "handles 8-bit integers" do
      yaml = """
      tlvs:
        - type: 3
          value: 255
      """
      
      assert {:ok, [tlv]} = YamlParser.parse(yaml)
      assert tlv.value == <<255>>
      assert tlv.length == 1
    end

    test "handles 16-bit integers" do
      yaml = """
      tlvs:
        - type: 3
          value: 65535
      """
      
      assert {:ok, [tlv]} = YamlParser.parse(yaml)
      assert tlv.value == <<255, 255>>
      assert tlv.length == 2
    end

    test "handles 32-bit integers" do
      yaml = """
      tlvs:
        - type: 3
          value: 4294967295
      """
      
      assert {:ok, [tlv]} = YamlParser.parse(yaml)
      assert tlv.value == <<255, 255, 255, 255>>
      assert tlv.length == 4
    end

    test "handles 64-bit integers" do
      yaml = """
      tlvs:
        - type: 3
          value: 18446744073709551615
      """
      
      assert {:ok, [tlv]} = YamlParser.parse(yaml)
      assert tlv.length == 8
      assert is_binary(tlv.value)
    end
  end

  describe "parse/1 error handling" do
    test "returns error for invalid YAML syntax" do
      yaml = """
      tlvs:
        - type: 3
        value: 1  # Invalid indentation
      """
      
      assert {:error, error_msg} = YamlParser.parse(yaml)
      assert error_msg =~ "YAML parsing error"
    end

    test "returns error for missing tlvs field" do
      yaml = """
      docsis_version: "3.1"
      """
      
      assert {:error, error_msg} = YamlParser.parse(yaml)
      assert error_msg == "Missing 'tlvs' array in YAML"
    end

    test "returns error for non-array tlvs field" do
      yaml = """
      tlvs: "not an array"
      """
      
      assert {:error, error_msg} = YamlParser.parse(yaml)
      assert error_msg == "Missing 'tlvs' array in YAML"
    end

    test "returns error for TLV without type field" do
      yaml = """
      tlvs:
        - value: 1
      """
      
      assert {:error, error_msg} = YamlParser.parse(yaml)
      assert error_msg =~ "TLV conversion error"
    end

    test "returns error for invalid TLV type" do
      yaml = """
      tlvs:
        - type: "invalid"
          value: 1
      """
      
      assert {:error, error_msg} = YamlParser.parse(yaml)
      assert error_msg =~ "TLV conversion error"
    end

    test "treats invalid hex string as regular string" do
      yaml = """
      tlvs:
        - type: 6
          value: "INVALID_HEX"
      """
      
      assert {:ok, [tlv]} = YamlParser.parse(yaml)
      assert tlv.type == 6
      assert tlv.value == "INVALID_HEX"
      assert tlv.length == 11
    end

    test "returns error for hex string with odd length" do
      yaml = """
      tlvs:
        - type: 6
          value: "AAB"
      """
      
      assert {:error, error_msg} = YamlParser.parse(yaml)
      assert error_msg =~ "TLV conversion error"
    end

    test "returns error for invalid byte array values" do
      yaml = """
      tlvs:
        - type: 6
          value: [256, 300]
      """
      
      assert {:error, error_msg} = YamlParser.parse(yaml)
      assert error_msg =~ "TLV conversion error"
    end

    test "returns error for unsupported value type" do
      yaml = """
      tlvs:
        - type: 6
          value: null
      """
      
      assert {:error, error_msg} = YamlParser.parse(yaml)
      assert error_msg =~ "TLV conversion error"
    end
  end

  describe "parse_file/1" do
    setup do
      # Create temporary test files
      valid_yaml = """
      tlvs:
        - type: 3
          value: 1
      """
      
      invalid_yaml = """
      tlvs:
        - type: 3
        value: 1  # Invalid indentation
      """
      
      valid_file = Path.join(System.tmp_dir!(), "valid_test.yaml")
      invalid_file = Path.join(System.tmp_dir!(), "invalid_test.yaml")
      nonexistent_file = Path.join(System.tmp_dir!(), "nonexistent.yaml")
      
      File.write!(valid_file, valid_yaml)
      File.write!(invalid_file, invalid_yaml)
      
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

    test "parses valid YAML file", %{valid_file: file} do
      assert {:ok, [tlv]} = YamlParser.parse_file(file)
      assert tlv.type == 3
      assert tlv.value == <<1>>
    end

    test "returns error for invalid YAML file", %{invalid_file: file} do
      assert {:error, error_msg} = YamlParser.parse_file(file)
      assert error_msg =~ "YAML parsing error"
    end

    test "returns error for nonexistent file", %{nonexistent_file: file} do
      assert {:error, error_msg} = YamlParser.parse_file(file)
      assert error_msg =~ "YAML parsing error"
    end
  end

  describe "validate_structure/1" do
    test "validates correct structure" do
      data = %{"tlvs" => [%{"type" => 3, "value" => 1}]}
      assert :ok = YamlParser.validate_structure(data)
    end

    test "rejects structure without tlvs" do
      data = %{"docsis_version" => "3.1"}
      assert {:error, _} = YamlParser.validate_structure(data)
    end

    test "rejects structure with non-array tlvs" do
      data = %{"tlvs" => "not an array"}
      assert {:error, _} = YamlParser.validate_structure(data)
    end

    test "rejects TLV without type" do
      data = %{"tlvs" => [%{"value" => 1}]}
      assert {:error, _} = YamlParser.validate_structure(data)
    end

    test "rejects TLV with invalid type" do
      data = %{"tlvs" => [%{"type" => 256, "value" => 1}]}
      assert {:error, _} = YamlParser.validate_structure(data)
    end
  end

  describe "normalize_yaml/1" do
    test "normalizes MAC address with colons" do
      yaml_data = %{"tlvs" => [%{"type" => 6, "value" => "aa:bb:cc:dd:ee:ff"}]}
      
      normalized = YamlParser.normalize_yaml(yaml_data)
      
      expected = %{"tlvs" => [%{"type" => 6, "value" => [170, 187, 204, 221, 238, 255]}]}
      assert normalized == expected
    end

    test "normalizes IP address with dots" do
      yaml_data = %{"tlvs" => [%{"type" => 4, "value" => "192.168.1.1"}]}
      
      normalized = YamlParser.normalize_yaml(yaml_data)
      
      expected = %{"tlvs" => [%{"type" => 4, "value" => [192, 168, 1, 1]}]}
      assert normalized == expected
    end

    test "leaves non-string values unchanged" do
      yaml_data = %{"tlvs" => [%{"type" => 3, "value" => 1}]}
      
      normalized = YamlParser.normalize_yaml(yaml_data)
      
      assert normalized == yaml_data
    end

    test "leaves non-MAC/IP strings unchanged for other TLV types" do
      yaml_data = %{"tlvs" => [%{"type" => 13, "value" => "test:string"}]}
      
      normalized = YamlParser.normalize_yaml(yaml_data)
      
      assert normalized == yaml_data
    end

    test "handles empty YAML data" do
      yaml_data = %{}
      
      normalized = YamlParser.normalize_yaml(yaml_data)
      
      assert normalized == yaml_data
    end
  end

  describe "complex real-world scenarios" do
    test "parses complete DOCSIS configuration" do
      yaml = """
      docsis_version: "3.1"
      tlvs:
        - type: 3
          value: 1
        - type: 4
          subtlvs:
            - type: 1
              value: 1
            - type: 2
              value: 1000000
            - type: 3
              value: 200000
            - type: 4
              value: 1
        - type: 17
          subtlvs:
            - type: 1
              value: 1
            - type: 6
              value: 0
            - type: 7
              value: 1000000
        - type: 21
          value: 5
        - type: 6
          value: "AA:BB:CC:DD:EE:FF:11:22:33:44:55:66:77:88:99:00"
        - type: 7
          value: "FF EE DD CC BB AA 00 99 88 77 66 55 44 33 22 11"
      """
      
      assert {:ok, tlvs} = YamlParser.parse(yaml)
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
      yaml = """
      tlvs:
        - type: 3
          value: 1
        - type: 13
          value: ServiceProvider
        - type: 6
          value: "AA BB CC DD"
        - type: 21
          value: [1, 2, 3, 4]
        - type: 50
          value: 3.14159
      """
      
      assert {:ok, tlvs} = YamlParser.parse(yaml)
      assert length(tlvs) == 5
      
      # Verify different value types are correctly converted
      [int_tlv, string_tlv, hex_tlv, array_tlv, float_tlv] = tlvs
      
      assert int_tlv.value == <<1>>
      assert string_tlv.value == "ServiceProvider"
      assert hex_tlv.value == <<170, 187, 204, 221>>
      assert array_tlv.value == <<1, 2, 3, 4>>
      assert float_tlv.value == <<3.14159::float-32>>
    end

    test "parses YAML with DOCSIS document markers" do
      yaml = """
      ---
      docsis_version: "3.1"
      tlvs:
        - type: 3
          value: 1
      ...
      """
      
      assert {:ok, [tlv]} = YamlParser.parse(yaml)
      assert tlv.type == 3
      assert tlv.value == <<1>>
    end

    test "handles YAML comments" do
      yaml = """
      # DOCSIS Configuration File
      docsis_version: "3.1"
      tlvs:
        # Network Access Control
        - type: 3
          value: 1  # Enabled
        # Max CPE Count
        - type: 21
          value: 5
      """
      
      assert {:ok, tlvs} = YamlParser.parse(yaml)
      assert length(tlvs) == 2
      assert Enum.map(tlvs, & &1.type) == [3, 21]
    end
  end

  describe "performance and edge cases" do
    @tag :performance
    test "handles large TLV arrays efficiently" do
      # Generate YAML for 1000 TLVs
      tlv_entries = for i <- 1..1000 do
        "  - type: #{rem(i, 255) + 1}\n    value: #{i}"
      end
      
      yaml = "tlvs:\n" <> Enum.join(tlv_entries, "\n")
      
      {time, {:ok, parsed_tlvs}} = :timer.tc(fn -> YamlParser.parse(yaml) end)
      
      assert length(parsed_tlvs) == 1000
      # Should parse within reasonable time (less than 1 second)
      assert time < 1_000_000
    end

    @tag :performance
    test "handles very large values" do
      large_hex = String.duplicate("AA", 5000)
      yaml = """
      tlvs:
        - type: 6
          value: "#{large_hex}"
      """
      
      assert {:ok, [tlv]} = YamlParser.parse(yaml)
      assert tlv.type == 6
      assert byte_size(tlv.value) == 5000
    end

    @tag :performance
    test "handles deeply nested subtlvs" do
      yaml = """
      tlvs:
        - type: 24
          subtlvs:
            - type: 22
              subtlvs:
                - type: 43
                  subtlvs:
                    - type: 1
                      value: 42
      """
      
      assert {:ok, [tlv]} = YamlParser.parse(yaml)
      assert tlv.type == 24
      assert is_binary(tlv.value)
    end

    test "handles YAML multiline strings" do
      yaml = """
      tlvs:
        - type: 13
          value: |
            This is a multiline
            service provider name
            that spans multiple lines
      """
      
      assert {:ok, [tlv]} = YamlParser.parse(yaml)
      assert tlv.type == 13
      assert is_binary(tlv.value)
      assert String.contains?(tlv.value, "multiline")
    end

    test "handles YAML folded strings" do
      yaml = """
      tlvs:
        - type: 13
          value: >
            This is a folded
            string that will
            be joined into
            a single line
      """
      
      assert {:ok, [tlv]} = YamlParser.parse(yaml)
      assert tlv.type == 13
      assert is_binary(tlv.value)
    end
  end
end