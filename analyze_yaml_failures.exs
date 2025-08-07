#!/usr/bin/env elixir

# Analyze YAML round-trip failures
IO.puts("=== YAML Round-trip Failure Analysis ===")

yaml_failures = [
  # Structure mismatch errors (work in JSON but fail in YAML)
  "PHS_last_tlvs.cm",
  "StaticMulticastSession.cm", 
  "TLV41_DsChannelList.cm",
  "TLV_22_43_12_DEMARCAutoConfiguration.cm",
  "TLV_22_43_4.cm",
  "TLV_22_43_6_ExtendedCMTSMICConfiguration.cm",
  "TLV_23_43_1_to_4_CMLoadBalancingPolicyID.cm",
  
  # Value parsing errors (integer out of range)
  "TLV_22_43_5_43_8_VendorSpecific.cm",  # Integer 803010203 out of range for uint8
  "TLV_22_43_7_SAVAuthorization.cm"     # Value out of range for uint32
]

IO.puts("Total YAML failures: #{length(yaml_failures)}")

# Categorize failures
structure_mismatch = [
  "PHS_last_tlvs.cm",
  "StaticMulticastSession.cm", 
  "TLV41_DsChannelList.cm",
  "TLV_22_43_12_DEMARCAutoConfiguration.cm",
  "TLV_22_43_4.cm",
  "TLV_22_43_6_ExtendedCMTSMICConfiguration.cm",
  "TLV_23_43_1_to_4_CMLoadBalancingPolicyID.cm"
]

value_parsing_errors = [
  "TLV_22_43_5_43_8_VendorSpecific.cm",
  "TLV_22_43_7_SAVAuthorization.cm"
]

IO.puts("\n=== Categories ===")
IO.puts("1. Structure mismatch (#{length(structure_mismatch)} files):")
Enum.each(structure_mismatch, fn file ->
  IO.puts("   - #{file}")
end)

IO.puts("\n2. Value parsing errors (#{length(value_parsing_errors)} files):")
IO.puts("   - TLV_22_43_5_43_8_VendorSpecific.cm: Integer 803010203 out of range for uint8")
IO.puts("   - TLV_22_43_7_SAVAuthorization.cm: Value out of range for uint32")

# Test a few files to understand the differences
IO.puts("\n=== Testing structure mismatch files ===")

test_files = ["PHS_last_tlvs.cm", "TLV41_DsChannelList.cm"]

Enum.each(test_files, fn filename ->
  path = "test/fixtures/#{filename}"
  if File.exists?(path) do
    binary = File.read!(path)
    
    IO.puts("\n--- #{filename} ---")
    IO.puts("Size: #{byte_size(binary)} bytes")
    
    try do
      {:ok, tlvs} = Bindocsis.parse(binary, enhanced: true)
      
      # Test JSON round-trip
      {:ok, json_str} = Bindocsis.Generators.JsonGenerator.generate(tlvs)
      {:ok, json_binary} = Bindocsis.HumanConfig.from_json(json_str)
      json_success = byte_size(binary) == byte_size(json_binary)
      
      # Test YAML round-trip  
      {:ok, yaml_str} = Bindocsis.Generators.YamlGenerator.generate(tlvs)
      case Bindocsis.HumanConfig.from_yaml(yaml_str) do
        {:ok, yaml_binary} ->
          yaml_success = byte_size(binary) == byte_size(yaml_binary)
          IO.puts("JSON: #{if json_success, do: "✅", else: "❌"} (#{byte_size(binary)} -> #{byte_size(json_binary)})")
          IO.puts("YAML: #{if yaml_success, do: "✅", else: "❌"} (#{byte_size(binary)} -> #{byte_size(yaml_binary)})")
          
          if !yaml_success do
            IO.puts("Size difference: #{byte_size(yaml_binary) - byte_size(binary)} bytes")
          end
          
        {:error, reason} ->
          IO.puts("JSON: #{if json_success, do: "✅", else: "❌"}")  
          IO.puts("YAML: ❌ Parse error: #{reason}")
      end
      
    rescue
      e -> IO.puts("Error: #{Exception.message(e)}")
    end
  end
end)

IO.puts("\n=== Recommendations ===")
IO.puts("1. Focus on structure mismatch files - these work in JSON but fail in YAML")
IO.puts("2. Check if YAML generator handles certain TLV types differently than JSON")
IO.puts("3. Investigate value parsing errors - may be YAML-specific integer handling")
IO.puts("4. These files represent edge cases that JSON handles but YAML doesn't")