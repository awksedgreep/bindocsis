#!/usr/bin/env elixir

# Debug the differences between YAML and JSON generation
IO.puts("=== YAML vs JSON Generation Differences ===")

test_files = [
  {"PHS_last_tlvs.cm", "YAML better"},
  {"TLV41_DsChannelList.cm", "JSON better"}
]

Enum.each(test_files, fn {filename, pattern} ->
  path = "test/fixtures/#{filename}"
  if File.exists?(path) do
    binary = File.read!(path)
    
    IO.puts("\n--- #{filename} (#{pattern}) ---")
    
    {:ok, tlvs} = Bindocsis.parse(binary, enhanced: true)
    
    # Generate both formats
    {:ok, json_str} = Bindocsis.Generators.JsonGenerator.generate(tlvs)
    {:ok, yaml_str} = Bindocsis.Generators.YamlGenerator.generate(tlvs)
    
    # Convert back to binary
    {:ok, json_binary} = Bindocsis.HumanConfig.from_json(json_str)
    {:ok, yaml_binary} = Bindocsis.HumanConfig.from_yaml(yaml_str)
    
    IO.puts("Original: #{byte_size(binary)} bytes")
    IO.puts("JSON:     #{byte_size(json_binary)} bytes (#{byte_size(json_binary) - byte_size(binary)})")
    IO.puts("YAML:     #{byte_size(yaml_binary)} bytes (#{byte_size(yaml_binary) - byte_size(binary)})")
    
    # Parse the results back to compare structures
    {:ok, orig_tlvs} = Bindocsis.parse(binary, enhanced: false)
    {:ok, json_tlvs} = Bindocsis.parse(json_binary, enhanced: false) 
    {:ok, yaml_tlvs} = Bindocsis.parse(yaml_binary, enhanced: false)
    
    IO.puts("\nTLV count comparison:")
    IO.puts("Original: #{length(orig_tlvs)} TLVs")
    IO.puts("JSON:     #{length(json_tlvs)} TLVs")
    IO.puts("YAML:     #{length(yaml_tlvs)} TLVs")
    
    # Compare TLV lengths
    IO.puts("\nTLV length comparison:")
    max_count = max(length(orig_tlvs), max(length(json_tlvs), length(yaml_tlvs)))
    
    for i <- 0..(max_count-1) do
      orig_tlv = Enum.at(orig_tlvs, i)
      json_tlv = Enum.at(json_tlvs, i) 
      yaml_tlv = Enum.at(yaml_tlvs, i)
      
      orig_info = if orig_tlv, do: "#{orig_tlv.type}:#{orig_tlv.length}", else: "missing"
      json_info = if json_tlv, do: "#{json_tlv.type}:#{json_tlv.length}", else: "missing"
      yaml_info = if yaml_tlv, do: "#{yaml_tlv.type}:#{yaml_tlv.length}", else: "missing"
      
      if orig_info != json_info or orig_info != yaml_info do
        IO.puts("  TLV #{i}: orig=#{orig_info}, json=#{json_info}, yaml=#{yaml_info}")
      end
    end
    
    # Look for specific issues
    if byte_size(json_binary) != byte_size(binary) do
      IO.puts("\n🔍 JSON issue detected")
    end
    
    if byte_size(yaml_binary) != byte_size(binary) do 
      IO.puts("\n🔍 YAML issue detected")
      
      # For YAML issues, check if it's related to specific TLV types
      if filename == "TLV41_DsChannelList.cm" do
        # This file has TLV 41 with malformed subtlvs
        tlv41_orig = Enum.find(orig_tlvs, &(&1.type == 41))
        tlv41_yaml = Enum.find(yaml_tlvs, &(&1.type == 41))
        
        if tlv41_orig && tlv41_yaml do
          IO.puts("  TLV 41: #{tlv41_orig.length} -> #{tlv41_yaml.length} (#{tlv41_yaml.length - tlv41_orig.length})")
        end
      end
    end
  end
end)

IO.puts("\n=== Analysis ===")
IO.puts("The YAML and JSON generators handle certain TLV structures differently.")
IO.puts("This suggests the issue is in the generation logic, not the parsing logic.")
IO.puts("Need to compare how YAML vs JSON generators handle specific TLV types.")