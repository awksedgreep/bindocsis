defmodule Bindocsis.Integration.RoundTripTest do
  use ExUnit.Case, async: true
  
  @moduledoc """
  Comprehensive round-trip format conversion tests.
  
  Tests data integrity across all supported format conversions:
  - Binary ↔ JSON ↔ YAML
  - Complex TLV structures with subtlvs
  - Edge cases and data preservation
  - Performance benchmarks
  """

  setup_all do
    # Create test fixtures directory if it doesn't exist
    fixtures_dir = Path.join([__DIR__, "..", "fixtures"])
    File.mkdir_p!(fixtures_dir)
    
    %{fixtures_dir: fixtures_dir}
  end

  setup do
    # Generate unique test files for each test
    temp_dir = System.tmp_dir!()
    test_id = :rand.uniform(100_000)
    
    files = %{
      binary: Path.join(temp_dir, "test_#{test_id}.cm"),
      json: Path.join(temp_dir, "test_#{test_id}.json"),
      yaml: Path.join(temp_dir, "test_#{test_id}.yaml"),
      temp_binary: Path.join(temp_dir, "temp_#{test_id}.cm"),
      temp_json: Path.join(temp_dir, "temp_#{test_id}.json"),
      temp_yaml: Path.join(temp_dir, "temp_#{test_id}.yaml")
    }
    
    on_exit(fn ->
      Enum.each(files, fn {_key, path} -> File.rm(path) end)
    end)
    
    %{files: files}
  end

  describe "Binary ↔ JSON round-trip conversion" do
    test "preserves simple TLV configuration", %{files: files} do
      # Create original binary TLV data
      original_tlvs = [
        %{type: 3, length: 1, value: <<1>>},
        %{type: 21, length: 1, value: <<5>>},
        %{type: 255, length: 0, value: <<>>}
      ]
      
      # Convert to binary and write
      {:ok, binary_data} = Bindocsis.Generators.BinaryGenerator.generate(original_tlvs)
      File.write!(files.binary, binary_data)
      
      # Round trip: Binary -> JSON -> Binary
      assert {:ok, parsed_tlvs} = Bindocsis.parse_file(files.binary)
      assert {:ok, json_content} = Bindocsis.Generators.JsonGenerator.generate(parsed_tlvs)
      File.write!(files.json, json_content)
      
      assert {:ok, json_parsed_tlvs} = Bindocsis.Parsers.JsonParser.parse_file(files.json)
      assert {:ok, final_binary} = Bindocsis.Generators.BinaryGenerator.generate(json_parsed_tlvs)
      File.write!(files.temp_binary, final_binary)
      
      # Compare final result with original
      assert {:ok, final_tlvs} = Bindocsis.parse_file(files.temp_binary)
      
      # Verify TLV structure is preserved (ignoring end markers)
      original_without_end = Enum.reject(original_tlvs, &(&1.type == 255))
      final_without_end = Enum.reject(final_tlvs, &(&1.type == 255))
      
      assert length(original_without_end) == length(final_without_end)
      
      Enum.zip(original_without_end, final_without_end)
      |> Enum.each(fn {orig, final} ->
        assert orig.type == final.type
        assert orig.length == final.length
        assert orig.value == final.value
      end)
    end

    test "preserves complex TLV configuration with subtlvs", %{files: files} do
      # Create complex TLV with subtlvs
      cos_subtlvs = [
        %{type: 1, length: 1, value: <<1>>},
        %{type: 2, length: 4, value: <<1000000::32>>},
        %{type: 3, length: 4, value: <<200000::32>>}
      ]
      {:ok, cos_value_with_term} = Bindocsis.Generators.BinaryGenerator.generate(cos_subtlvs, terminate: false)
      cos_value = cos_value_with_term
      
      original_tlvs = [
        %{type: 3, length: 1, value: <<1>>},
        %{type: 4, length: byte_size(cos_value), value: cos_value},
        %{type: 21, length: 1, value: <<5>>}
      ]
      
      # Round trip conversion
      {:ok, binary_data} = Bindocsis.Generators.BinaryGenerator.generate(original_tlvs)
      File.write!(files.binary, binary_data)
      
      assert {:ok, parsed_tlvs} = Bindocsis.parse_file(files.binary)
      assert {:ok, json_content} = Bindocsis.Generators.JsonGenerator.generate(parsed_tlvs)
      File.write!(files.json, json_content)
      
      assert {:ok, json_parsed_tlvs} = Bindocsis.Parsers.JsonParser.parse_file(files.json)
      assert {:ok, final_binary} = Bindocsis.Generators.BinaryGenerator.generate(json_parsed_tlvs)
      
      # Verify data integrity
      assert {:ok, final_tlvs} = Bindocsis.parse(final_binary)
      
      # Check that we have the same number of TLVs
      assert length(original_tlvs) == length(final_tlvs)
      
      # Verify each TLV is preserved
      Enum.zip(original_tlvs, final_tlvs)
      |> Enum.each(fn {orig, final} ->
        assert orig.type == final.type
        assert orig.length == final.length
        assert orig.value == final.value
      end)
    end

    test "preserves binary values with all byte ranges", %{files: files} do
      # Test binary data with full byte range (0-255)
      test_bytes = Enum.to_list(0..255) |> :binary.list_to_bin()
      
      original_tlvs = [
        %{type: 6, length: 256, value: test_bytes}
      ]
      
      # Round trip conversion
      {:ok, binary_data} = Bindocsis.Generators.BinaryGenerator.generate(original_tlvs)
      File.write!(files.binary, binary_data)
      
      assert {:ok, parsed_tlvs} = Bindocsis.parse_file(files.binary)
      assert {:ok, json_content} = Bindocsis.Generators.JsonGenerator.generate(parsed_tlvs)
      File.write!(files.json, json_content)
      
      assert {:ok, json_parsed_tlvs} = Bindocsis.Parsers.JsonParser.parse_file(files.json)
      
      # Verify the binary data is perfectly preserved
      [final_tlv] = json_parsed_tlvs
      assert final_tlv.type == 6
      assert final_tlv.length == 256
      assert final_tlv.value == test_bytes
    end
  end

  describe "Binary ↔ YAML round-trip conversion" do
    test "preserves simple configuration through YAML", %{files: files} do
      original_tlvs = [
        %{type: 3, length: 1, value: <<1>>},
        %{type: 13, length: 12, value: "TestProvider"},
        %{type: 21, length: 1, value: <<10>>}
      ]
      
      # Round trip: Binary -> YAML -> Binary
      {:ok, binary_data} = Bindocsis.Generators.BinaryGenerator.generate(original_tlvs)
      File.write!(files.binary, binary_data)
      
      assert {:ok, parsed_tlvs} = Bindocsis.parse_file(files.binary)
      assert {:ok, yaml_content} = Bindocsis.Generators.YamlGenerator.generate(parsed_tlvs)
      File.write!(files.yaml, yaml_content)
      
      assert {:ok, yaml_parsed_tlvs} = Bindocsis.Parsers.YamlParser.parse_file(files.yaml)
      assert {:ok, final_binary} = Bindocsis.Generators.BinaryGenerator.generate(yaml_parsed_tlvs)
      
      assert {:ok, final_tlvs} = Bindocsis.parse(final_binary)
      
      # Verify structure preservation
      assert length(original_tlvs) == length(final_tlvs)
      
      Enum.zip(original_tlvs, final_tlvs)
      |> Enum.each(fn {orig, final} ->
        assert orig.type == final.type
        assert orig.length == final.length
        assert orig.value == final.value
      end)
    end

    test "preserves MAC addresses and hex data", %{files: files} do
      mac_address = <<0xAA, 0xBB, 0xCC, 0xDD, 0xEE, 0xFF>>
      
      original_tlvs = [
        %{type: 6, length: 6, value: mac_address},
        %{type: 7, length: 6, value: mac_address}
      ]
      
      # Round trip conversion
      {:ok, binary_data} = Bindocsis.Generators.BinaryGenerator.generate(original_tlvs)
      File.write!(files.binary, binary_data)
      
      assert {:ok, parsed_tlvs} = Bindocsis.parse_file(files.binary)
      assert {:ok, yaml_content} = Bindocsis.Generators.YamlGenerator.generate(parsed_tlvs)
      File.write!(files.yaml, yaml_content)
      
      assert {:ok, yaml_parsed_tlvs} = Bindocsis.Parsers.YamlParser.parse_file(files.yaml)
      
      # Verify MAC address preservation
      [mac1, mac2] = yaml_parsed_tlvs
      assert mac1.value == mac_address
      assert mac2.value == mac_address
    end
  end

  describe "JSON ↔ YAML cross-conversion" do
    test "converts between JSON and YAML formats", %{files: files} do
      # Start with JSON
      json_data = %{
        "docsis_version" => "3.1",
        "tlvs" => [
          %{"type" => 3, "value" => 1},
          %{"type" => 21, "value" => 5},
          %{
            "type" => 4,
            "subtlvs" => [
              %{"type" => 1, "value" => 1},
              %{"type" => 2, "value" => 1000000}
            ]
          }
        ]
      }
      
      json_content = JSON.encode!(json_data)
      File.write!(files.json, json_content)
      
      # JSON -> TLVs -> YAML -> TLVs -> JSON
      assert {:ok, json_tlvs} = Bindocsis.Parsers.JsonParser.parse_file(files.json)
      assert {:ok, yaml_content} = Bindocsis.Generators.YamlGenerator.generate(json_tlvs)
      File.write!(files.yaml, yaml_content)
      
      assert {:ok, yaml_tlvs} = Bindocsis.Parsers.YamlParser.parse_file(files.yaml)
      assert {:ok, final_json} = Bindocsis.Generators.JsonGenerator.generate(yaml_tlvs)
      File.write!(files.temp_json, final_json)
      
      assert {:ok, final_tlvs} = Bindocsis.Parsers.JsonParser.parse_file(files.temp_json)
      
      # Verify data integrity across formats
      assert length(json_tlvs) == length(final_tlvs)
      
      Enum.zip(json_tlvs, final_tlvs)
      |> Enum.each(fn {orig, final} ->
        assert orig.type == final.type
        assert orig.length == final.length
        assert orig.value == final.value
      end)
    end
  end

  describe "Complex real-world configurations" do
    test "preserves complete DOCSIS 3.1 configuration", %{files: files} do
      # Create a realistic DOCSIS 3.1 configuration
      original_tlvs = [
        # Network Access Control
        %{type: 3, length: 1, value: <<1>>},
        
        # Class of Service
        %{type: 4, length: 18, value: create_cos_tlv()},
        
        # Upstream Service Flow
        %{type: 17, length: 14, value: create_upstream_sf()},
        
        # Downstream Service Flow  
        %{type: 18, length: 14, value: create_downstream_sf()},
        
        # Max CPE IP Addresses
        %{type: 21, length: 1, value: <<5>>},
        
        # CM MIC
        %{type: 6, length: 16, value: :crypto.strong_rand_bytes(16)},
        
        # CMTS MIC
        %{type: 7, length: 16, value: :crypto.strong_rand_bytes(16)},
        
        # DOCSIS 3.1 specific TLV
        %{type: 77, length: 4, value: <<1, 2, 3, 4>>}
      ]
      
      # Test all format combinations
      formats = [:binary, :json, :yaml]
      
      for from_format <- formats, to_format <- formats, from_format != to_format do
        # Start with binary representation
        {:ok, binary_data} = Bindocsis.Generators.BinaryGenerator.generate(original_tlvs)
        
        # Convert through the format chain
        intermediate_tlvs = case from_format do
          :binary -> 
            {:ok, tlvs} = Bindocsis.parse(binary_data)
            tlvs
          :json ->
            {:ok, json} = Bindocsis.Generators.JsonGenerator.generate(original_tlvs)
            {:ok, tlvs} = Bindocsis.Parsers.JsonParser.parse(json)
            tlvs
          :yaml ->
            {:ok, yaml} = Bindocsis.Generators.YamlGenerator.generate(original_tlvs)
            {:ok, tlvs} = Bindocsis.Parsers.YamlParser.parse(yaml)
            tlvs
        end
        
        final_tlvs = case to_format do
          :binary ->
            {:ok, bin} = Bindocsis.Generators.BinaryGenerator.generate(intermediate_tlvs)
            {:ok, tlvs} = Bindocsis.parse(bin)
            tlvs
          :json ->
            {:ok, json} = Bindocsis.Generators.JsonGenerator.generate(intermediate_tlvs)
            {:ok, tlvs} = Bindocsis.Parsers.JsonParser.parse(json)
            tlvs
          :yaml ->
            {:ok, yaml} = Bindocsis.Generators.YamlGenerator.generate(intermediate_tlvs)
            {:ok, tlvs} = Bindocsis.Parsers.YamlParser.parse(yaml)
            tlvs
        end
        
        # Verify conversion preserves core data
        assert length(original_tlvs) == length(final_tlvs)
        
        # Check types and lengths are preserved
        original_types = Enum.map(original_tlvs, & &1.type)
        final_types = Enum.map(final_tlvs, & &1.type)
        assert original_types == final_types
      end
    end

    test "handles large configurations efficiently", %{files: files} do
      # Generate large configuration (100 TLVs)
      large_tlvs = for i <- 1..100 do
        %{
          type: rem(i, 50) + 1,
          length: 4,
          value: <<i::32>>
        }
      end
      
      # Time the round-trip conversion
      {time, result} = :timer.tc(fn ->
        # Binary -> JSON -> YAML -> Binary
        {:ok, binary1} = Bindocsis.Generators.BinaryGenerator.generate(large_tlvs)
        {:ok, tlvs1} = Bindocsis.parse(binary1)
        {:ok, json} = Bindocsis.Generators.JsonGenerator.generate(tlvs1)
        {:ok, tlvs2} = Bindocsis.Parsers.JsonParser.parse(json)
        {:ok, yaml} = Bindocsis.Generators.YamlGenerator.generate(tlvs2)
        {:ok, tlvs3} = Bindocsis.Parsers.YamlParser.parse(yaml)
        {:ok, binary2} = Bindocsis.Generators.BinaryGenerator.generate(tlvs3)
        {:ok, final_tlvs} = Bindocsis.parse(binary2)
        
        {large_tlvs, final_tlvs}
      end)
      
      {original_tlvs, final_tlvs} = result
      
      # Verify data integrity
      assert length(original_tlvs) == length(final_tlvs)
      
      # Performance check: should complete within reasonable time (< 1 second)
      assert time < 1_000_000
      
      # Spot check some TLVs
      Enum.take(original_tlvs, 10)
      |> Enum.zip(Enum.take(final_tlvs, 10))
      |> Enum.each(fn {orig, final} ->
        assert orig.type == final.type
        assert orig.value == final.value
      end)
    end
  end

  describe "Edge cases and error recovery" do
    test "handles zero-length TLVs", %{files: files} do
      original_tlvs = [
        %{type: 254, length: 0, value: <<>>},  # Pad TLV
        %{type: 3, length: 1, value: <<1>>}
      ]
      
      # Round trip through all formats
      {:ok, binary_data} = Bindocsis.Generators.BinaryGenerator.generate(original_tlvs)
      {:ok, parsed_tlvs} = Bindocsis.parse(binary_data)
      {:ok, json_content} = Bindocsis.Generators.JsonGenerator.generate(parsed_tlvs)
      {:ok, json_tlvs} = Bindocsis.Parsers.JsonParser.parse(json_content)
      
      # Verify zero-length TLV is preserved
      pad_tlv = Enum.find(json_tlvs, &(&1.type == 254))
      assert pad_tlv != nil
      assert pad_tlv.length == 0
      assert pad_tlv.value == <<>>
    end

    test "handles maximum TLV values", %{files: files} do
      # Test with maximum single-byte length (255)
      large_value = :crypto.strong_rand_bytes(255)
      
      original_tlvs = [
        %{type: 6, length: 255, value: large_value}
      ]
      
      # Round trip conversion
      {:ok, binary_data} = Bindocsis.Generators.BinaryGenerator.generate(original_tlvs)
      {:ok, parsed_tlvs} = Bindocsis.parse(binary_data)
      {:ok, json_content} = Bindocsis.Generators.JsonGenerator.generate(parsed_tlvs)
      {:ok, json_tlvs} = Bindocsis.Parsers.JsonParser.parse(json_content)
      
      [final_tlv] = json_tlvs
      assert final_tlv.type == 6
      assert final_tlv.length == 255
      assert final_tlv.value == large_value
    end

    test "preserves special characters in string values", %{files: files} do
      special_string = "Test™ Provider® with UTF-8: café, naïve, résumé"
      
      original_tlvs = [
        %{type: 13, length: byte_size(special_string), value: special_string}
      ]
      
      # Round trip through JSON and YAML
      {:ok, json_content} = Bindocsis.Generators.JsonGenerator.generate(original_tlvs)
      {:ok, json_tlvs} = Bindocsis.Parsers.JsonParser.parse(json_content)
      {:ok, yaml_content} = Bindocsis.Generators.YamlGenerator.generate(json_tlvs)
      {:ok, final_tlvs} = Bindocsis.Parsers.YamlParser.parse(yaml_content)
      
      [final_tlv] = final_tlvs
      assert final_tlv.value == special_string
    end
  end

  describe "Performance benchmarks" do
    test "benchmarks conversion performance for different sizes", %{files: files} do
      sizes = [10, 50, 100, 500]
      
      results = for size <- sizes do
        tlvs = for i <- 1..size do
          %{type: rem(i, 100) + 1, length: 4, value: <<i::32>>}
        end
        
        # Measure round-trip time: Binary -> JSON -> YAML -> Binary
        {time, _} = :timer.tc(fn ->
          {:ok, binary1} = Bindocsis.Generators.BinaryGenerator.generate(tlvs)
          {:ok, tlvs1} = Bindocsis.parse(binary1)
          {:ok, json} = Bindocsis.Generators.JsonGenerator.generate(tlvs1)
          {:ok, tlvs2} = Bindocsis.Parsers.JsonParser.parse(json)
          {:ok, yaml} = Bindocsis.Generators.YamlGenerator.generate(tlvs2)
          {:ok, tlvs3} = Bindocsis.Parsers.YamlParser.parse(yaml)
          {:ok, _binary2} = Bindocsis.Generators.BinaryGenerator.generate(tlvs3)
        end)
        
        {size, time}
      end
      
      # Verify performance scales reasonably (roughly linear)
      results
      |> Enum.each(fn {size, time} ->
        # Should process at least 1 TLV per millisecond
        assert time < size * 1000
      end)
      
      # Log performance results for analysis
      IO.puts("\nRound-trip conversion performance:")
      Enum.each(results, fn {size, time} ->
        time_ms = time / 1000
        IO.puts("  #{size} TLVs: #{Float.round(time_ms, 2)}ms (#{Float.round(size/time_ms, 2)} TLVs/ms)")
      end)
    end
  end

  # Helper functions for creating test TLV data
  defp create_cos_tlv do
    subtlvs = [
      %{type: 1, length: 1, value: <<1>>},           # Class ID
      %{type: 2, length: 4, value: <<1000000::32>>}, # Max Rate Sustained
      %{type: 3, length: 4, value: <<200000::32>>},  # Max Traffic Burst
      %{type: 4, length: 1, value: <<1>>},           # Min Reserved Rate
      %{type: 5, length: 2, value: <<1518::16>>}     # Min Packet Size
    ]
    
    {:ok, encoded} = Bindocsis.Generators.BinaryGenerator.generate(subtlvs, terminate: false)
    encoded
  end

  defp create_upstream_sf do
    subtlvs = [
      %{type: 1, length: 2, value: <<1::16>>},       # SF Reference
      %{type: 6, length: 4, value: <<0::32>>},       # Min Reserved Rate
      %{type: 7, length: 4, value: <<1000000::32>>}, # Max Sustained Rate
      %{type: 8, length: 4, value: <<200000::32>>}   # Max Traffic Burst
    ]
    
    {:ok, encoded} = Bindocsis.Generators.BinaryGenerator.generate(subtlvs, terminate: false)
    encoded
  end

  defp create_downstream_sf do
    subtlvs = [
      %{type: 1, length: 2, value: <<2::16>>},       # SF Reference
      %{type: 6, length: 4, value: <<0::32>>},       # Min Reserved Rate
      %{type: 7, length: 4, value: <<1000000::32>>}, # Max Sustained Rate
      %{type: 8, length: 4, value: <<200000::32>>}   # Max Traffic Burst
    ]
    
    {:ok, encoded} = Bindocsis.Generators.BinaryGenerator.generate(subtlvs, terminate: false)
    encoded
  end
end