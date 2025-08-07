#!/usr/bin/env elixir

# Debug script to understand TLV 0 boolean parsing issues

defmodule TLV0Debug do
  def analyze_fixture(fixture_path) do
    IO.puts("Analyzing: #{Path.basename(fixture_path)}")
    
    binary = File.read!(fixture_path)
    {:ok, tlvs} = Bindocsis.parse(binary, enhanced: true)
    
    # Find any TLV that contains a subtlv with type 0
    Enum.each(tlvs, fn tlv ->
      if Map.has_key?(tlv, :subtlvs) and is_list(tlv.subtlvs) do
        check_for_tlv0(tlv, "Top-level TLV #{tlv.type}")
      end
    end)
    
    # Now test JSON round-trip to see where it fails
    IO.puts("\nTesting JSON round-trip...")
    case Bindocsis.HumanConfig.to_json(binary) do
      {:ok, json_content} ->
        case Bindocsis.HumanConfig.from_json(json_content) do
          {:ok, _} -> 
            IO.puts("✅ JSON round-trip successful")
          {:error, error} ->
            IO.puts("❌ JSON round-trip failed: #{error}")
            if String.contains?(error, "TLV 0") do
              IO.puts("   -> This is a TLV 0 error!")
              
              # Parse the JSON to look for TLV 0
              {:ok, parsed} = JSON.decode(json_content)
              find_tlv0_in_json(parsed["tlvs"], [])
            end
        end
      {:error, error} ->
        IO.puts("❌ JSON generation failed: #{error}")
    end
  end
  
  defp check_for_tlv0(tlv, path) do
    if tlv.type == 0 do
      IO.puts("Found TLV 0 at: #{path}")
      IO.puts("  value_type: #{tlv.value_type}")
      IO.puts("  value: #{inspect(tlv.value)}")
      IO.puts("  formatted_value: #{inspect(tlv.formatted_value)}")
    end
    
    if Map.has_key?(tlv, :subtlvs) and is_list(tlv.subtlvs) do
      Enum.each(tlv.subtlvs, fn subtlv ->
        check_for_tlv0(subtlv, "#{path} -> SubTLV #{subtlv.type}")
      end)
    end
  end
  
  defp find_tlv0_in_json(tlvs, path) when is_list(tlvs) do
    Enum.each(tlvs, fn tlv ->
      current_path = path ++ ["TLV #{tlv["type"]}"]
      
      if tlv["type"] == 0 do
        IO.puts("\nFound TLV 0 in JSON at: #{Enum.join(current_path, " -> ")}")
        IO.puts("  formatted_value: #{inspect(tlv["formatted_value"])}")
        IO.puts("  value_type: #{tlv["value_type"]}")
      end
      
      if tlv["subtlvs"] do
        find_tlv0_in_json(tlv["subtlvs"], current_path)
      end
    end)
  end
  
  defp find_tlv0_in_json(_, _), do: nil
end

# Test fixtures that are failing with TLV 0 errors
fixtures = [
  "test/fixtures/TLV37_SubMgmtFilters.cm",
  "test/fixtures/TLV_22_43_1_CMLoadBalancingPolicyID.cm"
]

Enum.each(fixtures, fn fixture ->
  if File.exists?(fixture) do
    TLV0Debug.analyze_fixture(fixture)
    IO.puts("\n" <> String.duplicate("=", 50) <> "\n")
  end
end)