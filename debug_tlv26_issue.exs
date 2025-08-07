#!/usr/bin/env elixir

# Debug TLV 26 length difference in PHS_last_tlvs.cm
IO.puts("=== TLV 26 Length Issue Analysis ===")

filename = "PHS_last_tlvs.cm"
path = "test/fixtures/#{filename}"

if File.exists?(path) do
  binary = File.read!(path)
  
  IO.puts("Original file: #{byte_size(binary)} bytes")
  
  # Parse with enhanced mode
  {:ok, tlvs} = Bindocsis.parse(binary, enhanced: true)
  
  # Find TLV 26
  tlv26 = Enum.find(tlvs, &(&1.type == 26))
  
  if tlv26 do
    IO.puts("\n--- Original TLV 26 ---")
    IO.puts("Type: #{tlv26.type}")
    IO.puts("Length: #{tlv26.length}")
    IO.puts("Value size: #{byte_size(tlv26.value)} bytes")
    IO.puts("Raw value: #{inspect(tlv26.value, limit: :infinity)}")
    
    if Map.has_key?(tlv26, :formatted_value) do
      IO.puts("Formatted value: #{inspect(tlv26.formatted_value)}")
    end
    
    # Generate JSON and see what happens to TLV 26
    {:ok, json_str} = Bindocsis.Generators.JsonGenerator.generate(tlvs)
    {:ok, json_binary} = Bindocsis.HumanConfig.from_json(json_str)
    
    # Parse JSON result
    {:ok, json_tlvs} = Bindocsis.parse(json_binary, enhanced: false)
    json_tlv26 = Enum.find(json_tlvs, &(&1.type == 26))
    
    IO.puts("\n--- JSON Round-trip TLV 26 ---")
    IO.puts("Type: #{json_tlv26.type}")
    IO.puts("Length: #{json_tlv26.length}")
    IO.puts("Value size: #{byte_size(json_tlv26.value)} bytes")
    IO.puts("Raw value: #{inspect(json_tlv26.value, limit: :infinity)}")
    
    # Generate YAML and see what happens to TLV 26
    {:ok, yaml_str} = Bindocsis.Generators.YamlGenerator.generate(tlvs)
    {:ok, yaml_binary} = Bindocsis.HumanConfig.from_yaml(yaml_str)
    
    # Parse YAML result
    {:ok, yaml_tlvs} = Bindocsis.parse(yaml_binary, enhanced: false)
    yaml_tlv26 = Enum.find(yaml_tlvs, &(&1.type == 26))
    
    IO.puts("\n--- YAML Round-trip TLV 26 ---")
    IO.puts("Type: #{yaml_tlv26.type}")
    IO.puts("Length: #{yaml_tlv26.length}")
    IO.puts("Value size: #{byte_size(yaml_tlv26.value)} bytes")
    IO.puts("Raw value: #{inspect(yaml_tlv26.value, limit: :infinity)}")
    
    # Compare the actual values
    IO.puts("\n--- Value Comparison ---")
    IO.puts("Original: #{inspect(tlv26.value, base: :hex)}")
    IO.puts("JSON:     #{inspect(json_tlv26.value, base: :hex)}")
    IO.puts("YAML:     #{inspect(yaml_tlv26.value, base: :hex)}")
    
    if tlv26.value != json_tlv26.value do
      IO.puts("❌ JSON changed the value!")
    else
      IO.puts("✅ JSON preserved the value")
    end
    
    if tlv26.value != yaml_tlv26.value do
      IO.puts("❌ YAML changed the value!")
      
      # Show byte-by-byte diff
      orig_bytes = :binary.bin_to_list(tlv26.value)
      yaml_bytes = :binary.bin_to_list(yaml_tlv26.value)
      
      IO.puts("\nByte-by-byte comparison:")
      IO.puts("Original: #{Enum.map_join(orig_bytes, " ", &(Integer.to_string(&1, 16) |> String.pad_leading(2, "0")))}")
      IO.puts("YAML:     #{Enum.map_join(yaml_bytes, " ", &(Integer.to_string(&1, 16) |> String.pad_leading(2, "0")))}")
    else
      IO.puts("✅ YAML preserved the value")
    end
    
    # Show the generated JSON and YAML for TLV 26
    IO.puts("\n--- Generated Formats ---")
    IO.puts("JSON snippet:")
    json_str |> String.split("\n") |> Enum.filter(&String.contains?(&1, "\"type\": 26")) |> Enum.each(&IO.puts("  #{&1}"))
    
    IO.puts("\nYAML snippet:")
    yaml_str |> String.split("\n") |> Enum.filter(&String.contains?(&1, "type: 26")) |> Enum.each(&IO.puts("  #{&1}"))
    
  else
    IO.puts("No TLV 26 found in file")
  end
else
  IO.puts("File #{path} not found")
end