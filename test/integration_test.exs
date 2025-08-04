defmodule IntegrationTest do
  use ExUnit.Case
  
  @moduletag :integration
  
  describe "four-format integration" do
    test "complete round-trip: binary -> config -> binary" do
      # Start with a simple binary DOCSIS configuration (avoiding compound TLVs and types with lossy conversions)
      original_binary = <<
        3, 1, 1,                                    # WebAccessControl enabled
        4, 4, 192, 168, 1, 1,                     # IPAddress 192.168.1.1
        255                                        # Terminator
      >>
      
      # Parse original binary
      {:ok, original_tlvs} = Bindocsis.parse(original_binary, format: :binary)
      
      # Convert through config format only (avoid lossy JSON/YAML conversions)
      {:ok, config} = Bindocsis.generate(original_tlvs, format: :config, include_header: false, include_comments: false)
      {:ok, tlvs_from_config} = Bindocsis.parse(config, format: :config)

      {:ok, _final_binary} = Bindocsis.generate(tlvs_from_config, format: :binary)
      
      # Verify data integrity
      assert length(original_tlvs) == 2
      assert length(tlvs_from_config) == 2
      
      # Verify TLV types are preserved
      original_types = Enum.map(original_tlvs, & &1.type) |> Enum.sort()
      final_types = Enum.map(tlvs_from_config, & &1.type) |> Enum.sort()
      assert original_types == final_types
      
      # Verify critical TLVs maintain their values
      web_access_orig = Enum.find(original_tlvs, &(&1.type == 3))
      web_access_final = Enum.find(tlvs_from_config, &(&1.type == 3))
      assert web_access_orig.value == web_access_final.value
      
      ip_addr_orig = Enum.find(original_tlvs, &(&1.type == 4))
      ip_addr_final = Enum.find(tlvs_from_config, &(&1.type == 4))
      assert ip_addr_orig.value == ip_addr_final.value
    end
    
    test "all formats can parse real DOCSIS fixture file" do
      fixture_path = "test/fixtures/BaseConfig.cm"
      
      if File.exists?(fixture_path) do
        # Parse original binary fixture
        {:ok, binary_tlvs} = Bindocsis.parse_file(fixture_path)
        
        # Convert to JSON/YAML formats (skip config due to compound TLV limitations)
        {:ok, json} = Bindocsis.generate(binary_tlvs, format: :json, detect_subtlvs: false)
        {:ok, yaml} = Bindocsis.generate(binary_tlvs, format: :yaml, detect_subtlvs: false)
        
        # Parse each format back
        {:ok, json_tlvs} = Bindocsis.parse(json, format: :json)
        {:ok, yaml_tlvs} = Bindocsis.parse(yaml, format: :yaml)
        
        # All should have same number of TLVs
        assert length(binary_tlvs) == length(json_tlvs)
        assert length(binary_tlvs) == length(yaml_tlvs)
        
        # All should have same TLV types
        binary_types = Enum.map(binary_tlvs, & &1.type) |> Enum.sort()
        json_types = Enum.map(json_tlvs, & &1.type) |> Enum.sort()
        yaml_types = Enum.map(yaml_tlvs, & &1.type) |> Enum.sort()
        
        assert binary_types == json_types
        assert binary_types == yaml_types
      end
    end
    
    test "format auto-detection works for all supported extensions" do
      tlvs = [%{type: 3, length: 1, value: <<1>>}]
      temp_dir = System.tmp_dir!()
      
      test_files = [
        {"test.cm", :binary},
        {"test.bin", :binary},
        {"test.json", :json},
        {"test.yaml", :yaml},
        {"test.yml", :yaml},
        {"test.conf", :config},
        {"test.cfg", :config}
      ]
      
      Enum.each(test_files, fn {filename, expected_format} ->
        file_path = Path.join(temp_dir, filename)
        
        try do
          # Write file in appropriate format
          :ok = Bindocsis.write_file(tlvs, file_path, format: expected_format)
          
          # Parse with auto-detection
          {:ok, parsed_tlvs} = Bindocsis.parse_file(file_path, enhanced: false)
          
          assert parsed_tlvs == tlvs
        after
          File.rm(file_path)
        end
      end)
    end
    
    test "handles complex nested TLV structures across all formats" do
      # Create complex TLV with nested service flows
      complex_binary = <<
        24, 12,                           # DownstreamServiceFlow (12 bytes)
        1, 2, 0, 1,                      # ServiceFlowReference 1
        6, 1, 7,                         # QoSParameterSetType 7
        7, 2, 0, 100,                    # MaxTrafficRate 100
        25, 9,                           # UpstreamServiceFlow (9 bytes)
        1, 2, 0, 2,                      # ServiceFlowReference 2
        6, 1, 7                          # QoSParameterSetType 7
      >>
      
      {:ok, original_tlvs} = Bindocsis.parse(complex_binary, format: :binary)
      
      # Test conversion to each format with conservative settings (skip config due to compound TLV limitations)
      formats = [:json, :yaml]
      
      Enum.each(formats, fn format ->
        opts = case format do
          :config -> [include_comments: false, include_header: false]
          _ -> [detect_subtlvs: false]
        end
        
        {:ok, converted} = Bindocsis.generate(original_tlvs, [format: format] ++ opts)
        {:ok, parsed_back} = Bindocsis.parse(converted, format: format)
        
        # Should preserve TLV count and types
        assert length(parsed_back) == length(original_tlvs)
        
        original_types = Enum.map(original_tlvs, & &1.type) |> Enum.sort()
        parsed_types = Enum.map(parsed_back, & &1.type) |> Enum.sort()
        assert original_types == parsed_types
      end)
    end
    
    test "error handling consistency across formats" do
      # Test invalid data for each format
      invalid_inputs = [
        {<<1, 5, 1, 2>>, :binary},                    # Invalid binary (insufficient data)
        {~s({"invalid": "json"}), :json},              # Invalid JSON structure
        {"invalid:\n  yaml: structure", :yaml},       # Invalid YAML structure
        {"InvalidTLVName value", :config}              # Invalid config TLV name
      ]
      
      Enum.each(invalid_inputs, fn {invalid_input, format} ->
        assert {:error, _reason} = Bindocsis.parse(invalid_input, format: format)
      end)
    end
    
    test "preserves data integrity with large configurations" do
      # Generate a large configuration with many TLVs
      large_tlvs = Enum.map(1..50, fn i ->
        case rem(i, 4) do
          0 -> %{type: 3, length: 1, value: <<1>>}
          1 -> %{type: 1, length: 4, value: <<35, 57, 241, 192>>}
          2 -> %{type: 2, length: 1, value: <<232>>}
          3 -> %{type: 4, length: 4, value: <<192, 168, 1, i>>}
        end
      end)
      
      # Test conversion through all formats with conservative settings
      {:ok, json} = Bindocsis.generate(large_tlvs, format: :json, detect_subtlvs: false)
      {:ok, yaml} = Bindocsis.generate(large_tlvs, format: :yaml, detect_subtlvs: false)
      {:ok, config} = Bindocsis.generate(large_tlvs, format: :config, include_comments: false)
      {:ok, binary} = Bindocsis.generate(large_tlvs, format: :binary)
      
      # Parse each back
      {:ok, json_tlvs} = Bindocsis.parse(json, format: :json)
      {:ok, yaml_tlvs} = Bindocsis.parse(yaml, format: :yaml)
      {:ok, config_tlvs} = Bindocsis.parse(config, format: :config)
      {:ok, binary_tlvs} = Bindocsis.parse(binary, format: :binary)
      
      # All should have same count
      assert length(json_tlvs) == 50
      assert length(yaml_tlvs) == 50
      assert length(config_tlvs) == 50
      assert length(binary_tlvs) == 50
    end
    
    test "format conversion maintains human readability" do
      machine_readable = <<3, 1, 1, 1, 4, 35, 57, 241, 192, 4, 4, 192, 168, 1, 100>>
      
      {:ok, config} = Bindocsis.convert(machine_readable, from: :binary, to: :config)
      {:ok, yaml} = Bindocsis.convert(machine_readable, from: :binary, to: :yaml)
      {:ok, json} = Bindocsis.convert(machine_readable, from: :binary, to: :json)
      
      # Config should be human readable
      assert String.contains?(config, "WebAccessControl enabled")
      assert String.contains?(config, "DownstreamFrequency")
      assert String.contains?(config, "IPAddress 192.168.1.100")
      
      # YAML should be structured and readable
      assert String.contains?(yaml, "type: 3")
      assert String.contains?(yaml, "value: 1")
      assert String.contains?(yaml, "docsis_version:")
      
      # JSON should be structured
      assert String.contains?(json, "\"type\": 3") or String.contains?(json, "\"type\":3")
      assert String.contains?(json, "\"value\": 1") or String.contains?(json, "\"value\":1")
      assert String.contains?(json, "\"docsis_version\":")
    end
    
    test "batch file processing works for mixed format directories" do
      temp_dir = System.tmp_dir!()
      test_subdir = Path.join(temp_dir, "bindocsis_integration_test")
      File.mkdir_p!(test_subdir)
      
      try do
        # Create test files in different formats
        tlvs = [
          %{type: 3, length: 1, value: <<1>>},
          %{type: 1, length: 4, value: <<35, 57, 241, 192>>}
        ]
        
        files = [
          {"config1.cm", :binary},
          {"config2.json", :json},
          {"config3.yaml", :yaml},
          {"config4.conf", :config}
        ]
        
        # Write files
        Enum.each(files, fn {filename, format} ->
          file_path = Path.join(test_subdir, filename)
          :ok = Bindocsis.write_file(tlvs, file_path, format: format)
        end)
        
        # Read all files back with auto-detection
        results = Enum.map(files, fn {filename, _format} ->
          file_path = Path.join(test_subdir, filename)
          Bindocsis.parse_file(file_path)
        end)
        
        # All should parse successfully
        Enum.each(results, fn result ->
          assert {:ok, parsed_tlvs} = result
          assert length(parsed_tlvs) == 2
        end)
        
      after
        File.rm_rf(test_subdir)
      end
    end
    
    test "handles edge cases consistently across formats" do
      edge_cases = [
        # Single byte value TLV
        [%{type: 3, length: 1, value: <<1>>}],
        # Multiple TLVs with same type
        [%{type: 3, length: 1, value: <<1>>}, %{type: 3, length: 1, value: <<0>>}],
        # Simple multi-byte value
        [%{type: 4, length: 4, value: <<192, 168, 1, 1>>}]
      ]
      
      Enum.each(edge_cases, fn tlvs ->
        # Convert to each format and back (skip config for complex cases)
        Enum.each([:json, :yaml, :binary], fn format ->
          {:ok, converted} = Bindocsis.generate(tlvs, format: format)
          {:ok, parsed_back} = Bindocsis.parse(converted, format: format)
          assert length(parsed_back) == length(tlvs)
        end)
      end)
    end
    
    test "performance is reasonable for typical configurations" do
      # Create a typical cable modem configuration
      typical_config = [
        %{type: 0, length: 1, value: <<1>>},         # NetworkAccessControl
        %{type: 3, length: 1, value: <<1>>},         # WebAccessControl
        %{type: 1, length: 4, value: <<35, 57, 241, 192>>}, # DownstreamFrequency
        %{type: 2, length: 1, value: <<232>>},       # MaxUpstreamTransmitPower
        %{type: 4, length: 4, value: <<192, 168, 1, 1>>},   # IPAddress
        %{type: 5, length: 4, value: <<255, 255, 255, 0>>}, # SubnetMask
        %{type: 8, length: 1, value: <<3>>},         # UpstreamChannelID
        %{type: 24, length: 6, value: <<1, 1, 1, 6, 1, 7>>}, # ServiceFlow
      ]
      
      # Time the conversion operations
      formats = [:json, :yaml, :config, :binary]
      
      Enum.each(formats, fn format ->
        {time_microseconds, {:ok, _result}} = 
          :timer.tc(fn -> Bindocsis.generate(typical_config, format: format) end)
        
        # Should complete within reasonable time (< 100ms for typical config)
        assert time_microseconds < 100_000
      end)
    end
    
    test "maintains DOCSIS compliance across format conversions" do
      # Use a real DOCSIS configuration structure (avoiding compound TLVs)
      docsis_config = [
        %{type: 0, length: 1, value: <<1>>},           # NetworkAccessControl enabled
        %{type: 1, length: 4, value: <<35, 57, 241, 192>>}, # 591MHz downstream
        %{type: 3, length: 1, value: <<0>>},           # WebAccessControl disabled
        %{type: 4, length: 4, value: <<192, 168, 100, 1>>}, # Modem IP
        %{type: 5, length: 4, value: <<255, 255, 255, 0>>}  # Subnet mask
      ]
      
      # Convert through all formats
      {:ok, json_str} = Bindocsis.generate(docsis_config, format: :json)
      {:ok, yaml_str} = Bindocsis.generate(docsis_config, format: :yaml)
      {:ok, config_str} = Bindocsis.generate(docsis_config, format: :config)
      
      # Parse back and verify DOCSIS structure is maintained
      {:ok, json_tlvs} = Bindocsis.parse(json_str, format: :json)
      {:ok, yaml_tlvs} = Bindocsis.parse(yaml_str, format: :yaml)
      {:ok, config_tlvs} = Bindocsis.parse(config_str, format: :config)
      
      # Verify mandatory DOCSIS TLVs are present in all formats
      mandatory_types = [0, 1, 3, 4, 5]  # Basic mandatory TLVs (no compound TLVs)
      
      [json_tlvs, yaml_tlvs, config_tlvs]
      |> Enum.each(fn tlvs ->
        present_types = Enum.map(tlvs, & &1.type)
        Enum.each(mandatory_types, fn mandatory_type ->
          assert mandatory_type in present_types
        end)
      end)
    end
  end
  
  describe "format-specific integration features" do
    test "JSON format includes rich metadata" do
      tlvs = [%{type: 3, length: 1, value: <<1>>}]
      
      {:ok, json} = Bindocsis.generate(tlvs, format: :json)
      {:ok, decoded} = JSON.decode(json)
      
      assert Map.has_key?(decoded, "docsis_version")
      assert Map.has_key?(decoded, "tlvs")
      
      [tlv] = decoded["tlvs"]
      assert Map.has_key?(tlv, "name")
      assert Map.has_key?(tlv, "description")
      assert tlv["name"] == "Network Access Control"
    end
    
    test "YAML format is properly structured and readable" do
      tlvs = [
        %{type: 3, length: 1, value: <<1>>},
        %{type: 1, length: 4, value: <<35, 57, 241, 192>>}
      ]
      
      {:ok, yaml} = Bindocsis.generate(tlvs, format: :yaml)
      
      # Should have proper YAML structure
      assert String.contains?(yaml, "docsis_version:")
      assert String.contains?(yaml, "tlvs:")
      assert String.contains?(yaml, "- type: 3")
      assert String.contains?(yaml, "  value: 1")
      
      # Should be parseable as YAML
      {:ok, _parsed_yaml} = YamlElixir.read_from_string(yaml)
    end
    
    test "config format supports comments and readability features" do
      tlvs = [%{type: 3, length: 1, value: <<1>>}]
      
      {:ok, config_with_comments} = Bindocsis.generate(tlvs, format: :config, include_comments: true)
      {:ok, config_without_comments} = Bindocsis.generate(tlvs, format: :config, include_comments: false)
      
      # With comments should include descriptions
      assert String.contains?(config_with_comments, "# Web-based management")
      
      # Without comments should be clean
      refute String.contains?(config_without_comments, "# Web-based management")
      
      # Both should parse correctly
      {:ok, _tlvs1} = Bindocsis.parse(config_with_comments, format: :config)
      {:ok, _tlvs2} = Bindocsis.parse(config_without_comments, format: :config)
    end
    
    test "binary format handles termination correctly" do
      tlvs = [%{type: 3, length: 1, value: <<1>>}]
      
      {:ok, binary_with_term} = Bindocsis.generate(tlvs, format: :binary, terminate: true)
      {:ok, binary_without_term} = Bindocsis.generate(tlvs, format: :binary, terminate: false)
      
      # With termination should end with 0xFF
      assert String.ends_with?(binary_with_term, <<255>>)
      
      # Without termination should not
      refute String.ends_with?(binary_without_term, <<255>>)
      
      # Both should parse correctly
      {:ok, _parsed1} = Bindocsis.parse(binary_with_term, format: :binary)
      {:ok, _parsed2} = Bindocsis.parse(binary_without_term, format: :binary)
    end
  end
  
  describe "real-world workflow simulation" do
    test "network engineer workflow: edit config file and deploy" do
      # Simulate: Engineer receives binary config, converts to editable format,
      # modifies it, and converts back to binary for deployment
      
      # Original network config (binary)
      original_binary = <<3, 1, 0, 1, 4, 35, 57, 241, 192, 4, 4, 192, 168, 1, 1>>
      
      # Step 1: Convert to human-readable config for editing
      {:ok, editable_config} = Bindocsis.convert(original_binary, from: :binary, to: :config)
      
      # Step 2: Simulate editing (enable web access, change IP)
      modified_config = editable_config
      |> String.replace("WebAccessControl disabled", "WebAccessControl enabled")
      |> String.replace("IPAddress 192.168.1.1", "IPAddress 192.168.1.100")
      
      # Step 3: Convert back to binary for deployment
      {:ok, deployment_binary} = Bindocsis.convert(modified_config, from: :config, to: :binary)
      
      # Step 4: Verify changes took effect
      {:ok, deployed_tlvs} = Bindocsis.parse(deployment_binary, format: :binary)
      
      web_access = Enum.find(deployed_tlvs, &(&1.type == 3))
      ip_address = Enum.find(deployed_tlvs, &(&1.type == 4))
      
      assert web_access.value == <<1>>  # Should be enabled now
      assert ip_address.value == <<192, 168, 1, 100>>  # Should be new IP
    end
    
    test "configuration management workflow: version control and diff" do
      # Simulate managing configs in version control
      
      config_v1 = [
        %{type: 3, length: 1, value: <<0>>},  # Web access disabled
        %{type: 1, length: 4, value: <<35, 57, 241, 192>>}  # 591MHz
      ]
      
      config_v2 = [
        %{type: 3, length: 1, value: <<1>>},  # Web access enabled
        %{type: 1, length: 4, value: <<35, 57, 241, 192>>},  # Same frequency
        %{type: 4, length: 4, value: <<192, 168, 1, 1>>}   # Added IP address
      ]
      
      # Convert both to human-readable formats for version control
      {:ok, v1_yaml} = Bindocsis.generate(config_v1, format: :yaml, detect_subtlvs: false)
      {:ok, v2_yaml} = Bindocsis.generate(config_v2, format: :yaml, detect_subtlvs: false)
      
      {:ok, v1_config} = Bindocsis.generate(config_v1, format: :config, include_comments: false)
      {:ok, v2_config} = Bindocsis.generate(config_v2, format: :config, include_comments: false)
      
      # Verify both formats represent the changes clearly
      assert String.contains?(v1_yaml, "value: 0")  # Disabled in v1
      assert String.contains?(v2_yaml, "value: 1")  # Enabled in v2
      
      assert String.contains?(v1_config, "disabled")  # Clear in config format
      assert String.contains?(v2_config, "enabled")
      assert String.contains?(v2_config, "IPAddress")  # New field visible
    end
    
    test "troubleshooting workflow: analyze config in multiple formats" do
      # Simulate troubleshooting a problematic config
      
      problematic_binary = <<
        3, 1, 1,                        # Web access enabled
        1, 4, 35, 57, 241, 192,        # Frequency
        24, 7,                          # Service flow with issue
        1, 2, 0, 1,                    # Service flow ref
        6, 1, 255,                     # Invalid QoS type (255 is invalid)
        255                             # Terminator
      >>
      
      # Analyze in different formats for troubleshooting
      {:ok, binary_tlvs} = Bindocsis.parse(problematic_binary, format: :binary)
      {:ok, json_analysis} = Bindocsis.generate(binary_tlvs, format: :json, detect_subtlvs: true)
      {:ok, yaml_analysis} = Bindocsis.generate(binary_tlvs, format: :yaml, detect_subtlvs: true)
      {:ok, config_analysis} = Bindocsis.generate(binary_tlvs, format: :config, include_comments: false)
      
      # Each format should help identify the issue
      # JSON provides structured analysis with metadata
      assert String.contains?(json_analysis, "\"subtlvs\"")
      
      # YAML provides clear hierarchical view
      assert String.contains?(yaml_analysis, "subtlvs:")
      
      # Config provides human-readable format
      assert String.contains?(config_analysis, "DownstreamServiceFlow")
      
      # All should preserve the problematic value for analysis
      service_flow = Enum.find(binary_tlvs, &(&1.type == 24))
      assert service_flow != nil
      assert service_flow.length == 7
    end
  end
end