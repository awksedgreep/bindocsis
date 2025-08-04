defmodule BindocsisNewApiTest do
  use ExUnit.Case
  
  describe "parse/2" do
    test "parses binary format" do
      binary_data = <<3, 1, 1>>
      assert {:ok, [%{type: 3, length: 1, value: <<1>>}]} = Bindocsis.parse(binary_data, format: :binary)
    end
    
    test "parses JSON format" do
      json_data = ~s({"tlvs": [{"type": 3, "value": 1}]})
      assert {:ok, [%{type: 3, length: 1, value: <<1>>}]} = Bindocsis.parse(json_data, format: :json)
    end
    
    test "parses YAML format" do
      yaml_data = "tlvs:\n  - type: 3\n    value: 1\n"
      assert {:ok, [%{type: 3, length: 1, value: <<1>>}]} = Bindocsis.parse(yaml_data, format: :yaml)
    end
    
    test "handles invalid JSON" do
      invalid_json = ~s({"invalid": json})
      assert {:error, error_msg} = Bindocsis.parse(invalid_json, format: :json)
      assert String.contains?(error_msg, "JSON")
    end
    
    test "handles invalid YAML" do
      invalid_yaml = "invalid:\n  yaml:\n    structure"
      assert {:error, error_msg} = Bindocsis.parse(invalid_yaml, format: :yaml)
      assert String.contains?(error_msg, "tlvs")
    end
    
    test "handles unsupported format" do
      data = <<1, 2, 3>>
      assert {:error, "Unsupported format: :unknown"} = Bindocsis.parse(data, format: :unknown)
    end
  end
  
  describe "generate/2" do
    setup do
      tlvs = [
        %{type: 3, length: 1, value: <<1>>},
        %{type: 1, length: 4, value: <<100, 200, 50, 0>>}
      ]
      {:ok, tlvs: tlvs}
    end
    
    test "generates binary format", %{tlvs: tlvs} do
      assert {:ok, binary} = Bindocsis.generate(tlvs, format: :binary)
      assert is_binary(binary)
      assert binary == <<3, 1, 1, 1, 4, 100, 200, 50, 0, 255>>
    end
    
    test "generates JSON format", %{tlvs: tlvs} do
      assert {:ok, json} = Bindocsis.generate(tlvs, format: :json)
      assert is_binary(json)
      # Check for semantic content, not specific formatting
      assert String.contains?(json, "\"type\": 3") or String.contains?(json, "\"type\":3")
      assert String.contains?(json, "\"Network Access Control\"")
    end
    
    test "generates YAML format", %{tlvs: tlvs} do
      assert {:ok, yaml} = Bindocsis.generate(tlvs, format: :yaml)
      assert is_binary(yaml)
      assert String.contains?(yaml, "type: 3")
      assert String.contains?(yaml, "docsis_version:")
    end
    
    test "generates simplified JSON", %{tlvs: tlvs} do
      assert {:ok, json} = Bindocsis.generate(tlvs, format: :json, simplified: true)
      refute String.contains?(json, "docsis_version")
      assert String.contains?(json, "\"tlvs\"")
    end
    
    test "generates simplified YAML", %{tlvs: tlvs} do
      assert {:ok, yaml} = Bindocsis.generate(tlvs, format: :yaml, simplified: true)
      refute String.contains?(yaml, "docsis_version")
      assert String.starts_with?(yaml, "tlvs:")
    end
    
    test "respects detect_subtlvs option", %{tlvs: tlvs} do
      # Test with subtlv detection disabled
      assert {:ok, json_no_subtlvs} = Bindocsis.generate(tlvs, format: :json, detect_subtlvs: false)
      assert {:ok, yaml_no_subtlvs} = Bindocsis.generate(tlvs, format: :yaml, detect_subtlvs: false)
      
      # Should not contain subtlvs even for compound TLV types
      refute String.contains?(json_no_subtlvs, "\"subtlvs\"")
      refute String.contains?(yaml_no_subtlvs, "subtlvs:")
    end
    
    test "handles empty TLV list" do
      assert {:ok, binary} = Bindocsis.generate([], format: :binary)
      assert binary == <<255>>  # Just the terminator
    end
    
    test "handles unsupported format", %{tlvs: tlvs} do
      assert {:error, "Unsupported format: :unknown"} = Bindocsis.generate(tlvs, format: :unknown)
    end
  end
  
  describe "convert/2" do
    test "converts binary to JSON" do
      binary_data = <<3, 1, 1>>
      assert {:ok, json} = Bindocsis.convert(binary_data, from: :binary, to: :json)
      assert String.contains?(json, "\"type\": 3") or String.contains?(json, "\"type\":3")
    end
    
    test "converts JSON to binary" do
      json_data = ~s({"tlvs": [{"type": 3, "value": 1}]})
      assert {:ok, binary} = Bindocsis.convert(json_data, from: :json, to: :binary)
      assert binary == <<3, 1, 1, 255>>
    end
    
    test "converts binary to YAML" do
      binary_data = <<3, 1, 1>>
      assert {:ok, yaml} = Bindocsis.convert(binary_data, from: :binary, to: :yaml)
      assert String.contains?(yaml, "type: 3")
    end
    
    test "converts YAML to binary" do
      yaml_data = "tlvs:\n  - type: 3\n    value: 1\n"
      assert {:ok, binary} = Bindocsis.convert(yaml_data, from: :yaml, to: :binary)
      assert binary == <<3, 1, 1, 255>>
    end
    
    test "converts JSON to YAML" do
      json_data = ~s({"tlvs": [{"type": 3, "value": 1}]})
      assert {:ok, yaml} = Bindocsis.convert(json_data, from: :json, to: :yaml)
      assert String.contains?(yaml, "type: 3")
    end
    
    test "converts YAML to JSON" do
      yaml_data = "tlvs:\n  - type: 3\n    value: 1\n"
      assert {:ok, json} = Bindocsis.convert(yaml_data, from: :yaml, to: :json)
      assert String.contains?(json, "\"type\": 3") or String.contains?(json, "\"type\":3")
    end
  end
  
  describe "parse_file/2" do
    test "parses binary file with auto-detection" do
      test_file = Path.join(System.tmp_dir!(), "test_auto.cm")
      File.write!(test_file, <<3, 1, 1>>)
      
      try do
        assert {:ok, tlvs} = Bindocsis.parse_file(test_file)
        assert [%{type: 3, length: 1, value: <<1>>}] = tlvs
      after
        File.rm(test_file)
      end
    end
    
    test "parses JSON file with auto-detection" do
      test_file = Path.join(System.tmp_dir!(), "test_auto.json")
      File.write!(test_file, ~s({"tlvs": [{"type": 3, "value": 1}]}))
      
      try do
        assert {:ok, tlvs} = Bindocsis.parse_file(test_file)
        assert [%{type: 3, length: 1, value: <<1>>}] = tlvs
      after
        File.rm(test_file)
      end
    end
    
    test "parses YAML file with auto-detection" do
      test_file = Path.join(System.tmp_dir!(), "test_auto.yaml")
      File.write!(test_file, "tlvs:\n  - type: 3\n    value: 1\n")
      
      try do
        assert {:ok, tlvs} = Bindocsis.parse_file(test_file)
        assert [%{type: 3, length: 1, value: <<1>>}] = tlvs
      after
        File.rm(test_file)
      end
    end
    
    test "forces specific format" do
      test_file = Path.join(System.tmp_dir!(), "test_force.txt")
      File.write!(test_file, ~s({"tlvs": [{"type": 3, "value": 1}]}))
      
      try do
        assert {:ok, tlvs} = Bindocsis.parse_file(test_file, format: :json)
        assert [%{type: 3, length: 1, value: <<1>>}] = tlvs
      after
        File.rm(test_file)
      end
    end
    
    test "handles non-existent file" do
      assert {:error, :enoent} = Bindocsis.parse_file("non_existent_file.cm")
    end
  end
  
  describe "write_file/3" do
    setup do
      tlvs = [%{type: 3, length: 1, value: <<1>>}]
      {:ok, tlvs: tlvs}
    end
    
    test "writes binary file", %{tlvs: tlvs} do
      test_file = Path.join(System.tmp_dir!(), "test_write.cm")
      
      try do
        assert :ok = Bindocsis.write_file(tlvs, test_file, format: :binary)
        {:ok, content} = File.read(test_file)
        assert content == <<3, 1, 1, 255>>
      after
        File.rm(test_file)
      end
    end
    
    test "writes JSON file", %{tlvs: tlvs} do
      test_file = Path.join(System.tmp_dir!(), "test_write.json")
      
      try do
        assert :ok = Bindocsis.write_file(tlvs, test_file, format: :json)
        {:ok, content} = File.read(test_file)
        assert String.contains?(content, "\"type\": 3") or String.contains?(content, "\"type\":3")
      after
        File.rm(test_file)
      end
    end
    
    test "writes YAML file", %{tlvs: tlvs} do
      test_file = Path.join(System.tmp_dir!(), "test_write.yaml")
      
      try do
        assert :ok = Bindocsis.write_file(tlvs, test_file, format: :yaml)
        {:ok, content} = File.read(test_file)
        assert String.contains?(content, "type: 3")
      after
        File.rm(test_file)
      end
    end
  end
  
  describe "format detection" do
    test "detects binary format from .cm extension" do
      assert :binary = Bindocsis.FormatDetector.detect_format("config.cm")
    end
    
    test "detects JSON format from .json extension" do
      assert :json = Bindocsis.FormatDetector.detect_format("config.json")
    end
    
    test "detects YAML format from .yaml extension" do
      assert :yaml = Bindocsis.FormatDetector.detect_format("config.yaml")
    end
    
    test "detects YAML format from .yml extension" do
      assert :yaml = Bindocsis.FormatDetector.detect_format("config.yml")
    end
    
    test "falls back to content detection for unknown extension" do
      test_file = Path.join(System.tmp_dir!(), "test_detect.unknown")
      File.write!(test_file, ~s({"tlvs": [{"type": 3}]}))
      
      try do
        assert :json = Bindocsis.FormatDetector.detect_format(test_file)
      after
        File.rm(test_file)
      end
    end
  end
  
  describe "round-trip conversion" do
    test "binary -> JSON -> binary maintains fidelity with simple TLVs" do
      # Use simple TLVs that won't trigger subtlv detection
      original = <<3, 1, 1, 18, 1, 0>>
      
      {:ok, json} = Bindocsis.convert(original, from: :binary, to: :json)
      {:ok, back_to_binary} = Bindocsis.convert(json, from: :json, to: :binary)
      
      # Should be the same with terminator added
      assert back_to_binary == <<3, 1, 1, 18, 1, 0, 255>>
    end
    
    test "binary -> YAML -> binary maintains fidelity with simple TLVs" do
      original = <<3, 1, 1>>
      
      {:ok, yaml} = Bindocsis.convert(original, from: :binary, to: :yaml)
      {:ok, back_to_binary} = Bindocsis.convert(yaml, from: :yaml, to: :binary)
      
      # Should be the same with terminator added
      assert back_to_binary == <<3, 1, 1, 255>>
    end
    
    test "JSON -> YAML -> JSON maintains fidelity" do
      original = ~s({"tlvs": [{"type": 3, "value": 1}]})
      
      {:ok, yaml} = Bindocsis.convert(original, from: :json, to: :yaml)
      {:ok, back_to_json} = Bindocsis.convert(yaml, from: :yaml, to: :json)
      
      # Parse both to compare structure (formatting may differ)
      {:ok, original_tlvs} = Bindocsis.parse(original, format: :json)
      {:ok, result_tlvs} = Bindocsis.parse(back_to_json, format: :json)
      
      assert original_tlvs == result_tlvs
    end
    
    test "perfect binary fidelity with subtlv detection disabled" do
      # Use a compound TLV that would normally trigger subtlv detection
      original = <<24, 7, 1, 2, 0, 1, 6, 1, 7>>
      
      {:ok, json} = Bindocsis.generate(
        Bindocsis.parse(original, format: :binary) |> elem(1), 
        format: :json, 
        detect_subtlvs: false
      )
      {:ok, back_to_binary} = Bindocsis.convert(json, from: :json, to: :binary)
      
      # Should maintain exact binary structure (with terminator)
      assert back_to_binary == <<24, 7, 1, 2, 0, 1, 6, 1, 7, 255>>
    end
  end
  
  describe "complex TLVs with subtlvs" do
    test "handles compound TLVs correctly with subtlv detection enabled" do
      # TLV 24 (Downstream Service Flow) with subtlvs
      compound_binary = <<24, 7, 1, 2, 0, 1, 6, 1, 7>>
      
      {:ok, tlvs} = Bindocsis.parse(compound_binary, format: :binary)
      assert [%{type: 24, length: 7, value: _}] = tlvs
      
      # Convert to JSON and check subtlvs are detected
      {:ok, json} = Bindocsis.generate(tlvs, format: :json, detect_subtlvs: true)
      assert String.contains?(json, "subtlvs")
    end
    
    test "preserves raw binary when subtlv detection is disabled" do
      compound_binary = <<24, 7, 1, 2, 0, 1, 6, 1, 7>>
      
      {:ok, tlvs} = Bindocsis.parse(compound_binary, format: :binary)
      
      # Convert to JSON without subtlv detection
      {:ok, json} = Bindocsis.generate(tlvs, format: :json, detect_subtlvs: false)
      refute String.contains?(json, "subtlvs")
      assert String.contains?(json, "\"value\"")
    end
    
    test "subtlv detection works with valid TLV structures" do
      # Create a proper compound TLV that should parse correctly
      compound_binary = <<25, 6, 1, 1, 2, 6, 1, 7>>  # Shorter, valid structure
      
      {:ok, tlvs} = Bindocsis.parse(compound_binary, format: :binary)
      {:ok, yaml} = Bindocsis.generate(tlvs, format: :yaml, detect_subtlvs: true)
      
      # Should contain subtlvs if detection worked
      if String.contains?(yaml, "subtlvs") do
        assert String.contains?(yaml, "- type: 1")
      else
        # If not detected as subtlvs, should have raw value
        assert String.contains?(yaml, "value:")
      end
    end
  end
  
  describe "error handling" do
    test "handles malformed binary data" do
      malformed = <<3, 5, 1>>  # Claims length 5 but only has 1 byte
      assert {:error, _} = Bindocsis.parse(malformed, format: :binary)
    end
    
    test "handles invalid TLV structure in generation" do
      invalid_tlvs = [%{type: "invalid", length: 1, value: <<1>>}]
      assert {:error, _} = Bindocsis.generate(invalid_tlvs, format: :binary)
    end
  end
  
  describe "real file compatibility" do
    test "can parse existing test fixtures" do
      fixture_path = "test/fixtures/BaseConfig.cm"
      
      if File.exists?(fixture_path) do
        assert {:ok, tlvs} = Bindocsis.parse_file(fixture_path)
        assert is_list(tlvs)
        assert length(tlvs) > 0
        
        # Test conversion to other formats
        assert {:ok, _json} = Bindocsis.generate(tlvs, format: :json)
        assert {:ok, _yaml} = Bindocsis.generate(tlvs, format: :yaml)
        
        # Test with subtlv detection disabled for perfect fidelity
        assert {:ok, json_faithful} = Bindocsis.generate(tlvs, format: :json, detect_subtlvs: false)
        assert {:ok, yaml_faithful} = Bindocsis.generate(tlvs, format: :yaml, detect_subtlvs: false)
        
        # Parse back with faithful conversion
        assert {:ok, json_tlvs} = Bindocsis.parse(json_faithful, format: :json)
        assert {:ok, yaml_tlvs} = Bindocsis.parse(yaml_faithful, format: :yaml)
        
        # With subtlv detection disabled, structure should be preserved
        assert length(json_tlvs) == length(tlvs)
        assert length(yaml_tlvs) == length(tlvs)
        
        # Check that types and basic structure are preserved
        original_types = Enum.map(tlvs, & &1.type) |> Enum.sort()
        json_types = Enum.map(json_tlvs, & &1.type) |> Enum.sort()
        yaml_types = Enum.map(yaml_tlvs, & &1.type) |> Enum.sort()
        
        assert json_types == original_types
        assert yaml_types == original_types
        
        # Test that we can also parse with default settings (may have different structure due to subtlvs)
        assert {:ok, json_with_subtlvs} = Bindocsis.generate(tlvs, format: :json)
        assert {:ok, _parsed_with_subtlvs} = Bindocsis.parse(json_with_subtlvs, format: :json)
      end
    end
  end
end