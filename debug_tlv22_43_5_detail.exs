#!/usr/bin/env elixir

# Debug the nested structure in detail
fixture_path = "test/fixtures/TLV_22_43_5_2_4_2_MPLSPeerIpAddress.cm"
binary_data = File.read!(fixture_path)

# Parse with enhancement
{:ok, tlvs} = Bindocsis.parse(binary_data, enhanced: true)

# Find TLV 22
tlv22 = Enum.find(tlvs, &(&1.type == 22))

defmodule DebugHelper do
  def print_tlv_tree(tlv, indent \\ 0) do
    prefix = String.duplicate("  ", indent)
    IO.puts("#{prefix}TLV #{tlv.type}: length=#{tlv.length}, value_type=#{tlv.value_type}")
    
    if tlv.formatted_value do
      IO.puts("#{prefix}  formatted_value: #{inspect(tlv.formatted_value, limit: 50)}")
    end
    
    if tlv.subtlvs && length(tlv.subtlvs) > 0 do
      IO.puts("#{prefix}  Subtlvs (#{length(tlv.subtlvs)}):")
      Enum.each(tlv.subtlvs, &print_tlv_tree(&1, indent + 2))
    elsif tlv.value_type == :compound do
      IO.puts("#{prefix}  (compound but no subtlvs parsed)")
    end
  end
end

IO.puts("Original TLV 22 structure:")
DebugHelper.print_tlv_tree(tlv22)

# Generate JSON and parse back
{:ok, json_str} = Bindocsis.Generators.JsonGenerator.generate(tlvs)
{:ok, reparsed_binary} = Bindocsis.HumanConfig.from_json(json_str)
{:ok, final_tlvs} = Bindocsis.parse(reparsed_binary, enhanced: true)

final_tlv22 = Enum.find(final_tlvs, &(&1.type == 22))

IO.puts("\nFinal TLV 22 structure:")
DebugHelper.print_tlv_tree(final_tlv22)

# Now compare specific subtlv chains
defmodule CompareHelper do
  def find_nested_tlv(tlv, path) do
    case path do
      [] -> tlv
      [type | rest] ->
        if tlv.subtlvs do
          subtlv = Enum.find(tlv.subtlvs, &(&1.type == type))
          if subtlv, do: find_nested_tlv(subtlv, rest), else: nil
        else
          nil
        end
    end
  end
end

# Check the deeply nested TLV 22 -> 43 -> 5 -> 2 -> 4 chain
path = [43, 5, 2, 4]
orig_nested = CompareHelper.find_nested_tlv(tlv22, path)
final_nested = CompareHelper.find_nested_tlv(final_tlv22, path)

if orig_nested && final_nested do
  IO.puts("\nComparing TLV 22.43.5.2.4:")
  IO.puts("  Original: length=#{orig_nested.length}, subtlvs=#{length(orig_nested.subtlvs || [])}")
  IO.puts("  Final: length=#{final_nested.length}, subtlvs=#{length(final_nested.subtlvs || [])}")
  
  if orig_nested.subtlvs && final_nested.subtlvs do
    IO.puts("\n  Original subtlvs:")
    Enum.each(orig_nested.subtlvs, fn s ->
      IO.puts("    TLV #{s.type}: length=#{s.length}")
    end)
    
    IO.puts("\n  Final subtlvs:")
    Enum.each(final_nested.subtlvs, fn s ->
      IO.puts("    TLV #{s.type}: length=#{s.length}")
    end)
  end
else
  IO.puts("\nCould not find TLV 22.43.5.2.4 in one or both structures")
end