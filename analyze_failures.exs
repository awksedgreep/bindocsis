#!/usr/bin/env elixir

# Analyze each failing file to identify patterns
failing_files = [
  # YAML & JSON failures
  "StaticMulticastSession.cm",
  "TLV41_DsChannelList.cm", 
  "TLV_22_43_12_DEMARCAutoConfiguration.cm",
  "TLV_22_43_5_2_4_2_MPLSPeerIpAddress.cm",
  "TLV_22_43_5_2_4_ServiceMultiplexingValueMPLSPW.cm",
  "TLV_22_43_5_2_6_IEEE8021ahEncapsulation.cm",
  # JSON only failures
  "TLV_22_43_5_3_to_9.cm",
  "TLV_22_43_9_CMAttributeMasks.cm",
  "TLV_23_43_5_24_SOAMSubtype.cm",
  "TLV_23_43_last_tlvs.cm",
  # YAML only failures  
  "PHS_last_tlvs.cm",
  "TLV_22_43_4.cm"
]

IO.puts("# Failure Analysis Report\n")
IO.puts("## Files with Issues\n")

Enum.each(failing_files, fn filename ->
  path = "test/fixtures/#{filename}"
  if File.exists?(path) do
    binary = File.read!(path)
    
    IO.puts("### #{filename}")
    IO.puts("- Size: #{byte_size(binary)} bytes")
    
    # Parse and analyze
    case Bindocsis.parse(binary, enhanced: true) do
      {:ok, tlvs} ->
        # Count compound TLVs
        compound_count = count_compound_tlvs(tlvs)
        IO.puts("- TLVs: #{length(tlvs)}")
        IO.puts("- Compound TLVs: #{compound_count}")
        
        # Check for specific problem TLVs
        problem_tlvs = []
        
        # Check for TLV 22 or 23 (packet classification)
        if Enum.any?(tlvs, &(&1.type in [22, 23])) do
          problem_tlvs = ["packet classification" | problem_tlvs]
        end
        
        # Check for TLV 41 (subscriber management)
        if Enum.any?(tlvs, &(&1.type == 41)) do
          problem_tlvs = ["subscriber management" | problem_tlvs]
        end
        
        # Check for TLV 43 in nested contexts
        if has_nested_tlv43?(tlvs) do
          problem_tlvs = ["nested L2VPN (43)" | problem_tlvs]
        end
        
        # Check for vendor TLVs
        if Enum.any?(tlvs, &(&1.type >= 200 and &1.type <= 254)) do
          problem_tlvs = ["vendor-specific" | problem_tlvs]
        end
        
        if length(problem_tlvs) > 0 do
          IO.puts("- Problem areas: #{Enum.join(problem_tlvs, ", ")}")
        end
        
        # Test JSON round-trip
        case test_json_roundtrip(tlvs) do
          {:ok, :match} -> 
            IO.puts("- JSON: ✅ Success")
          {:error, reason} ->
            IO.puts("- JSON: ❌ #{reason}")
        end
        
        # Test YAML round-trip
        case test_yaml_roundtrip(tlvs) do
          {:ok, :match} ->
            IO.puts("- YAML: ✅ Success")
          {:error, reason} ->
            IO.puts("- YAML: ❌ #{reason}")
        end
        
      {:error, reason} ->
        IO.puts("- Parse error: #{reason}")
    end
    
    IO.puts("")
  end
end)

# Move helper functions outside the Enum.each
nil

# Define all helper functions
def count_compound_tlvs(tlvs) do
  Enum.reduce(tlvs, 0, fn tlv, acc ->
    if Map.get(tlv, :value_type) == :compound do
      1 + acc + count_compound_tlvs(Map.get(tlv, :subtlvs, []))
    else
      acc
    end
  end)
end

def has_nested_tlv43?(tlvs) do
  Enum.any?(tlvs, fn tlv ->
    subtlvs = Map.get(tlv, :subtlvs, [])
    if subtlvs != [] do
      Enum.any?(subtlvs, &(&1.type == 43)) or has_nested_tlv43?(subtlvs)
    else
      false
    end
  end)
end

def test_json_roundtrip(tlvs) do
  try do
    {:ok, json} = Bindocsis.Generators.JsonGenerator.generate(tlvs)
    {:ok, binary} = Bindocsis.HumanConfig.from_json(json)
    {:ok, final_tlvs} = Bindocsis.parse(binary, enhanced: true)
    
    if compare_tlv_structure(tlvs, final_tlvs) do
      {:ok, :match}
    else
      {:error, "Structure mismatch"}
    end
  rescue
    e -> {:error, "Exception: #{Exception.message(e)}"}
  end
end

def test_yaml_roundtrip(tlvs) do
  try do
    {:ok, yaml} = Bindocsis.Generators.YamlGenerator.generate(tlvs)
    {:ok, binary} = Bindocsis.HumanConfig.from_yaml(yaml)
    {:ok, final_tlvs} = Bindocsis.parse(binary, enhanced: true)
    
    if compare_tlv_structure(tlvs, final_tlvs) do
      {:ok, :match}
    else
      {:error, "Structure mismatch"}
    end
  rescue
    e -> {:error, "Exception: #{Exception.message(e)}"}
  end
end

def compare_tlv_structure(tlvs1, tlvs2) do
  length(tlvs1) == length(tlvs2) and
  Enum.zip(tlvs1, tlvs2) |> Enum.all?(fn {t1, t2} ->
    t1.type == t2.type and t1.length == t2.length
  end)
end