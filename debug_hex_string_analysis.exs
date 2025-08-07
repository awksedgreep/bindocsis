#!/usr/bin/env elixir

# Debug script to analyze hex_string TLV behavior and round-trip failures
# This will help us understand why the hex_string exclusivity fix didn't improve success rates

defmodule HexStringAnalysis do
  def analyze_fixture(fixture_path) do
    IO.puts("🔍 Analyzing fixture: #{Path.basename(fixture_path)}")
    
    case Bindocsis.parse(File.read!(fixture_path), format: :binary, enhanced: true) do
      {:ok, enhanced_tlvs} ->
        # Count TLVs by value_type
        type_counts = Enum.reduce(enhanced_tlvs, %{}, fn tlv, acc ->
          type = tlv.value_type
          Map.update(acc, type, 1, &(&1 + 1))
        end)
        
        hex_string_tlvs = Enum.filter(enhanced_tlvs, fn tlv -> tlv.value_type == :hex_string end)
        
        IO.puts("📊 TLV value_type distribution:")
        Enum.each(type_counts, fn {type, count} ->
          IO.puts("  #{type}: #{count}")
        end)
        
        IO.puts("\n🔧 Hex string TLVs found: #{length(hex_string_tlvs)}")
        
        if length(hex_string_tlvs) > 0 do
          IO.puts("📝 Hex string TLV details:")
          Enum.each(hex_string_tlvs, fn tlv ->
            hex_preview = tlv.formatted_value |> String.slice(0, 20)
            IO.puts("  TLV #{tlv.type} (#{tlv.name}): \"#{hex_preview}...\"")
          end)
        end
        
        # Test JSON round-trip
        case Bindocsis.HumanConfig.to_json(File.read!(fixture_path)) do
          {:ok, json_content} ->
            IO.puts("\n✅ JSON generation successful")
            
            case Bindocsis.HumanConfig.from_json(json_content) do
              {:ok, _binary_data} ->
                IO.puts("✅ JSON round-trip successful!")
              {:error, error} ->
                IO.puts("❌ JSON round-trip failed: #{error}")
                
                # Try to extract the specific error details
                if String.contains?(error, "hex_string") do
                  IO.puts("🎯 This is a hex_string related error!")
                end
            end
          {:error, error} ->
            IO.puts("❌ JSON generation failed: #{error}")
        end
        
      {:error, error} ->
        IO.puts("❌ Failed to parse fixture: #{error}")
    end
    
    IO.puts("\n" <> String.duplicate("=", 50) <> "\n")
  end
end

# Analyze a few key failing fixtures
fixtures_to_analyze = [
  "test/fixtures/BaseConfig.cm",
  "test/fixtures/TLV37_SubMgmtFilters.cm",
  "test/fixtures/TLV_22_43_1_CMLoadBalancingPolicyID.cm"
]

IO.puts("🚀 Starting hex_string TLV analysis...")
IO.puts("This will help us understand why hex_string exclusivity didn't improve success rates.\n")

Enum.each(fixtures_to_analyze, fn fixture_path ->
  if File.exists?(fixture_path) do
    HexStringAnalysis.analyze_fixture(fixture_path)
  else
    IO.puts("⚠️ Fixture not found: #{fixture_path}")
  end
end)