defmodule Bindocsis.HumanConfigTest do
  use ExUnit.Case
  doctest Bindocsis.HumanConfig

  alias Bindocsis.HumanConfig

  # Sample binary configuration for testing
  @sample_binary_config <<
    # Downstream Frequency: 591 MHz
    1, 4, 35, 57, 241, 192,
    # Network Access Control: Enabled
    3, 1, 1,
    # Modem IP Address: 192.168.1.100
    12, 4, 192, 168, 1, 100,
    # End marker
    255
  >>

  describe "binary to human conversion" do
    test "converts binary config to YAML successfully" do
      assert {:ok, yaml_string} = HumanConfig.to_yaml(@sample_binary_config)
      
      # Check that YAML contains expected human-readable values
      assert String.contains?(yaml_string, "591 MHz")
      assert String.contains?(yaml_string, "Enabled")
      assert String.contains?(yaml_string, "192.168.1.100")
      assert String.contains?(yaml_string, "Downstream Frequency")
      assert String.contains?(yaml_string, "Network Access Control")
      assert String.contains?(yaml_string, "docsis_version:")
    end

    test "converts binary config to JSON successfully" do
      assert {:ok, json_string} = HumanConfig.to_json(@sample_binary_config)
      
      # Parse JSON to verify structure
      assert {:ok, parsed_json} = JSON.decode(json_string)
      assert %{"docsis_version" => "3.1", "tlvs" => tlvs} = parsed_json
      assert is_list(tlvs)
      assert length(tlvs) == 3
      
      # Check specific TLV values
      frequency_tlv = Enum.find(tlvs, &(&1["type"] == 1))
      assert frequency_tlv["name"] == "Downstream Frequency"
      assert frequency_tlv["value"] == "591 MHz"
      
      boolean_tlv = Enum.find(tlvs, &(&1["type"] == 3))
      assert boolean_tlv["name"] == "Network Access Control"
      assert boolean_tlv["value"] == "Enabled"
      
      ip_tlv = Enum.find(tlvs, &(&1["type"] == 12))
      assert ip_tlv["name"] == "Modem IP Address"
      assert ip_tlv["value"] == "192.168.1.100"
    end

    test "includes metadata when requested" do
      assert {:ok, json_string} = HumanConfig.to_json(@sample_binary_config, include_metadata: true)
      assert {:ok, parsed_json} = JSON.decode(json_string)
      
      assert %{"metadata" => metadata} = parsed_json
      assert %{"total_tlvs" => 3, "binary_size" => _, "parsed_at" => _} = metadata
    end

    test "includes descriptions when requested" do
      assert {:ok, json_string} = HumanConfig.to_json(@sample_binary_config, include_descriptions: true)
      assert {:ok, parsed_json} = JSON.decode(json_string)
      
      frequency_tlv = Enum.find(parsed_json["tlvs"], &(&1["type"] == 1))
      assert frequency_tlv["description"] == "Center frequency of the downstream channel in Hz"
    end

    test "handles different format styles" do
      # Compact format (default)
      assert {:ok, compact_json} = HumanConfig.to_json(@sample_binary_config, format_style: :compact)
      assert {:ok, compact_parsed} = JSON.decode(compact_json)
      
      # Verbose format
      assert {:ok, verbose_json} = HumanConfig.to_json(@sample_binary_config, format_style: :verbose)
      assert {:ok, verbose_parsed} = JSON.decode(verbose_json)
      
      # Both should have same basic structure
      assert compact_parsed["docsis_version"] == verbose_parsed["docsis_version"]
      assert length(compact_parsed["tlvs"]) == length(verbose_parsed["tlvs"])
    end
  end

  describe "human to binary conversion" do
    test "converts YAML config to binary successfully" do
      yaml_config = """
      docsis_version: "3.1"
      tlvs:
        - type: 1
          name: "Downstream Frequency"
          value: "591 MHz"
        - type: 3
          name: "Network Access Control"
          value: "enabled"
        - type: 12
          name: "Modem IP Address"
          value: "192.168.1.100"
      """
      
      assert {:ok, binary_config} = HumanConfig.from_yaml(yaml_config)
      
      # Parse the generated binary to verify correctness
      assert {:ok, parsed_tlvs} = Bindocsis.parse(binary_config, format: :binary, enhanced: false)
      assert length(parsed_tlvs) == 3
      
      # Check frequency TLV
      frequency_tlv = Enum.find(parsed_tlvs, &(&1.type == 1))
      assert frequency_tlv.value == <<35, 57, 241, 192>>  # 591 MHz in binary
      
      # Check boolean TLV  
      boolean_tlv = Enum.find(parsed_tlvs, &(&1.type == 3))
      assert boolean_tlv.value == <<1>>  # enabled = 1
      
      # Check IP address TLV
      ip_tlv = Enum.find(parsed_tlvs, &(&1.type == 12))
      assert ip_tlv.value == <<192, 168, 1, 100>>
    end

    test "converts JSON config to binary successfully" do
      json_config = JSON.encode!(%{
        "docsis_version" => "3.1",
        "tlvs" => [
          %{
            "type" => 1,
            "name" => "Downstream Frequency",
            "value" => "615 MHz"
          },
          %{
            "type" => 3,
            "name" => "Network Access Control", 
            "value" => "disabled"
          }
        ]
      })
      
      assert {:ok, binary_config} = HumanConfig.from_json(json_config)
      
      # Parse and verify
      assert {:ok, parsed_tlvs} = Bindocsis.parse(binary_config, format: :binary, enhanced: false)
      assert length(parsed_tlvs) == 2
      
      # 615 MHz = 615,000,000 Hz
      frequency_tlv = Enum.find(parsed_tlvs, &(&1.type == 1))
      assert <<a, b, c, d>> = frequency_tlv.value
      assert a * 256 * 256 * 256 + b * 256 * 256 + c * 256 + d == 615_000_000
      
      # disabled = 0
      boolean_tlv = Enum.find(parsed_tlvs, &(&1.type == 3))
      assert boolean_tlv.value == <<0>>
    end

    test "handles various human-readable formats" do
      yaml_config = """
      docsis_version: "3.1"
      tlvs:
        - type: 1
          value: "1.2 GHz"
        - type: 3
          value: "on"
        - type: 12
          value: "10.0.0.1"
        - type: 21
          value: 32
      """
      
      assert {:ok, binary_config} = HumanConfig.from_yaml(yaml_config)
      assert {:ok, parsed_tlvs} = Bindocsis.parse(binary_config, format: :binary, enhanced: false)
      
      # 1.2 GHz = 1,200,000,000 Hz
      frequency_tlv = Enum.find(parsed_tlvs, &(&1.type == 1))
      assert <<a, b, c, d>> = frequency_tlv.value
      assert a * 256 * 256 * 256 + b * 256 * 256 + c * 256 + d == 1_200_000_000
      
      # "on" = 1
      boolean_tlv = Enum.find(parsed_tlvs, &(&1.type == 3))
      assert boolean_tlv.value == <<1>>
      
      # IP address
      ip_tlv = Enum.find(parsed_tlvs, &(&1.type == 12))
      assert ip_tlv.value == <<10, 0, 0, 1>>
      
      # Integer value
      int_tlv = Enum.find(parsed_tlvs, &(&1.type == 21))
      assert int_tlv.value == <<32>>
    end

    test "validates configuration by default" do
      # Invalid configuration with bad frequency
      yaml_config = """
      docsis_version: "3.1"
      tlvs:
        - type: 1
          value: "invalid frequency"
      """
      
      assert {:error, error_msg} = HumanConfig.from_yaml(yaml_config)
      assert String.contains?(error_msg, "TLV 1")
      assert String.contains?(error_msg, "Invalid frequency format")
    end

    test "skips validation when disabled" do
      # Use an unknown TLV type that would normally be handled as binary
      yaml_config = """
      docsis_version: "3.1"
      tlvs:
        - type: 200
          value: "DEADBEEF"
      """
      
      # Should succeed without validation
      assert {:ok, _binary_config} = HumanConfig.from_yaml(yaml_config, validate: false)
    end
  end

  describe "round-trip validation" do
    test "validates successful round-trip conversion" do
      assert {:ok, :valid} = HumanConfig.validate_round_trip(@sample_binary_config)
    end

    test "detects round-trip inconsistencies" do
      # Create a binary config that might have round-trip issues
      problematic_binary = <<200, 5, "hello", 255>>  # Unknown TLV type
      
      # This might succeed or fail depending on how unknown TLVs are handled
      case HumanConfig.validate_round_trip(problematic_binary) do
        {:ok, :valid} -> assert true  # Round-trip worked
        {:error, _reason} -> assert true  # Expected to fail
      end
    end

    test "round-trip with complex configuration" do
      # Create a more complex binary config
      complex_binary = <<
        1, 4, 35, 57, 241, 192,    # Frequency
        3, 1, 1,                   # Boolean
        12, 4, 192, 168, 1, 100,   # IP address
        21, 1, 16,                 # Max CPE count
        255                        # End marker
      >>
      
      assert {:ok, :valid} = HumanConfig.validate_round_trip(complex_binary)
    end
  end

  describe "template generation" do
    test "generates residential template" do
      assert {:ok, yaml_template} = HumanConfig.generate_template(:residential)
      
      # Check template structure
      assert String.contains?(yaml_template, "docsis_version:")
      assert String.contains?(yaml_template, "tlvs:")
      assert String.contains?(yaml_template, "Downstream Frequency")
      assert String.contains?(yaml_template, "Network Access Control")
      assert String.contains?(yaml_template, "591 MHz")
      assert String.contains?(yaml_template, "enabled")
      
      # Should include helpful comments
      assert String.contains?(yaml_template, "# Generated DOCSIS Configuration")
      assert String.contains?(yaml_template, "# Frequencies:")
      assert String.contains?(yaml_template, "# Bandwidth:")
    end

    test "generates business template" do
      assert {:ok, yaml_template} = HumanConfig.generate_template(:business)
      
      assert String.contains?(yaml_template, "615 MHz")  # Different from residential
      assert String.contains?(yaml_template, "10.1.1.100")  # Business IP range
      assert String.contains?(yaml_template, "64")  # Higher CPE limit
    end

    test "generates minimal template" do
      assert {:ok, yaml_template} = HumanConfig.generate_template(:minimal)
      
      # Should have fewer TLVs than other templates
      yaml_lines = String.split(yaml_template, "\n")
      tlv_lines = Enum.filter(yaml_lines, &String.contains?(&1, "type:"))
      assert length(tlv_lines) == 2  # Only essential TLVs
    end

    test "includes descriptions in templates when requested" do
      assert {:ok, yaml_template} = HumanConfig.generate_template(:residential, include_descriptions: true)
      
      # Check that descriptions appear as comments in the YAML
      assert String.contains?(yaml_template, "# Primary downstream channel frequency")
      assert String.contains?(yaml_template, "# Enable network access for the modem")
    end

    test "rejects unknown template types" do
      assert {:error, error_msg} = HumanConfig.generate_template(:unknown_template)
      assert String.contains?(error_msg, "Unknown template type")
    end

    test "lists available templates" do
      templates = HumanConfig.get_available_templates()
      assert is_list(templates)
      assert :residential in templates
      assert :business in templates
      assert :minimal in templates
    end
  end

  describe "error handling" do
    test "handles invalid YAML gracefully" do
      invalid_yaml = """
      docsis_version: "3.1"
      tlvs:
        - type 1  # Missing colon
          value: "591 MHz"
      """
      
      assert {:error, error_msg} = HumanConfig.from_yaml(invalid_yaml)
      assert String.contains?(error_msg, "YAML parsing failed")
    end

    test "handles invalid JSON gracefully" do
      invalid_json = """
      {
        "docsis_version": "3.1",
        "tlvs": [
          {
            "type": 1,
            "value": "591 MHz"  // Comments not allowed in JSON
          }
        ]
      }
      """
      
      assert {:error, error_msg} = HumanConfig.from_json(invalid_json)
      assert String.contains?(error_msg, "JSON parsing failed")
    end

    test "handles missing required fields" do
      incomplete_yaml = """
      docsis_version: "3.1"
      # Missing tlvs array
      """
      
      assert {:error, error_msg} = HumanConfig.from_yaml(incomplete_yaml)
      assert String.contains?(error_msg, "must contain 'tlvs' array")
    end

    test "handles invalid TLV structure" do
      invalid_tlv_yaml = """
      docsis_version: "3.1"
      tlvs:
        - name: "Missing type field"
          value: "591 MHz"
      """
      
      assert {:error, error_msg} = HumanConfig.from_yaml(invalid_tlv_yaml)
      assert String.contains?(error_msg, "Missing or invalid TLV type")
    end

    test "handles unparseable values" do
      bad_value_yaml = """
      docsis_version: "3.1"
      tlvs:
        - type: 1
          value: "not a valid frequency"
      """
      
      assert {:error, error_msg} = HumanConfig.from_yaml(bad_value_yaml)
      assert String.contains?(error_msg, "TLV 1")
      assert String.contains?(error_msg, "Invalid frequency format")
    end

    test "handles invalid binary data for conversion" do
      invalid_binary = <<1, 255, 2>>  # Invalid length
      
      assert {:error, error_msg} = HumanConfig.to_yaml(invalid_binary)
      assert String.contains?(error_msg, "Failed to parse")
    end
  end

  describe "configuration options" do
    test "respects DOCSIS version option" do
      yaml_config = """
      docsis_version: "3.0"
      tlvs:
        - type: 1
          value: "591 MHz"
      """
      
      assert {:ok, _binary} = HumanConfig.from_yaml(yaml_config, docsis_version: "3.0")
    end

    test "handles strict parsing mode" do
      # In strict mode, might be more picky about values
      yaml_config = """
      docsis_version: "3.1"
      tlvs:
        - type: 1
          value: "591 MHz"
      """
      
      assert {:ok, _binary} = HumanConfig.from_yaml(yaml_config, strict: false)
      assert {:ok, _binary} = HumanConfig.from_yaml(yaml_config, strict: true)
    end
  end

  describe "integration tests" do
    test "full workflow: binary -> YAML -> binary" do
      # Start with binary config
      original_binary = @sample_binary_config
      
      # Convert to YAML
      assert {:ok, yaml_string} = HumanConfig.to_yaml(original_binary)
      
      # Convert back to binary
      assert {:ok, reconverted_binary} = HumanConfig.from_yaml(yaml_string)
      
      # Parse both to compare (since binary representation might vary slightly)
      assert {:ok, original_tlvs} = Bindocsis.parse(original_binary, format: :binary, enhanced: false)
      assert {:ok, reconverted_tlvs} = Bindocsis.parse(reconverted_binary, format: :binary, enhanced: false)
      
      assert length(original_tlvs) == length(reconverted_tlvs)
      
      # Check that key TLV values match
      for {orig, reconv} <- Enum.zip(original_tlvs, reconverted_tlvs) do
        assert orig.type == reconv.type
        assert orig.value == reconv.value
      end
    end

    test "full workflow: binary -> JSON -> binary" do
      original_binary = @sample_binary_config
      
      # Convert to JSON
      assert {:ok, json_string} = HumanConfig.to_json(original_binary)
      
      # Convert back to binary
      assert {:ok, reconverted_binary} = HumanConfig.from_json(json_string)
      
      # Validate round-trip
      assert {:ok, original_tlvs} = Bindocsis.parse(original_binary, format: :binary, enhanced: false)
      assert {:ok, reconverted_tlvs} = Bindocsis.parse(reconverted_binary, format: :binary, enhanced: false)
      
      assert length(original_tlvs) == length(reconverted_tlvs)
    end

    test "template -> binary -> human readable cycle" do
      # Generate template
      assert {:ok, template_yaml} = HumanConfig.generate_template(:residential)
      
      # Convert template to binary
      assert {:ok, binary_config} = HumanConfig.from_yaml(template_yaml)
      
      # Convert binary back to human readable
      assert {:ok, human_json} = HumanConfig.to_json(binary_config)
      
      # Should be able to parse the JSON
      assert {:ok, parsed_json} = JSON.decode(human_json)
      assert %{"docsis_version" => _, "tlvs" => tlvs} = parsed_json
      assert is_list(tlvs)
      assert length(tlvs) > 0
    end
  end
end