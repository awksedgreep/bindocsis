#!/usr/bin/env elixir

# Simple analysis of L2VPN structure issues
filename = "TLV_22_43_5_2_4_2_MPLSPeerIpAddress.cm"
path = "test/fixtures/#{filename}"
binary = File.read!(path)

IO.puts("=== #{filename} ===")
IO.puts("Original size: #{byte_size(binary)} bytes")

# Parse original
{:ok, tlvs} = Bindocsis.parse(binary, enhanced: true)

# Generate JSON 
{:ok, json_str} = Bindocsis.Generators.JsonGenerator.generate(tlvs)

# Try round-trip
{:ok, reparsed_binary} = Bindocsis.HumanConfig.from_json(json_str)
{:ok, final_tlvs} = Bindocsis.parse(reparsed_binary, enhanced: true)

IO.puts("Reparsed size: #{byte_size(reparsed_binary)} bytes")
IO.puts("Size difference: #{byte_size(reparsed_binary) - byte_size(binary)} bytes")

# Find the main TLV 22/23
orig_main = Enum.find(tlvs, &(&1.type in [22, 23]))
final_main = Enum.find(final_tlvs, &(&1.type in [22, 23]))

if orig_main && final_main do
  IO.puts("\nMain TLV #{orig_main.type}:")
  IO.puts("  Original length: #{orig_main.length}")
  IO.puts("  Final length: #{final_main.length}")
  IO.puts("  Length difference: #{final_main.length - orig_main.length}")
  
  # Check subtlvs count
  orig_subtlvs = Map.get(orig_main, :subtlvs, [])
  final_subtlvs = Map.get(final_main, :subtlvs, [])
  
  IO.puts("  Original subtlvs: #{length(orig_subtlvs)}")
  IO.puts("  Final subtlvs: #{length(final_subtlvs)}")
  
  # Compare first level subtlvs
  if length(orig_subtlvs) > 0 && length(final_subtlvs) > 0 do
    IO.puts("\n  Subtlv comparison:")
    Enum.zip(orig_subtlvs, final_subtlvs) 
    |> Enum.each(fn {orig, final} ->
      IO.puts("    TLV #{orig.type}: #{orig.length} -> #{final.length} (#{final.length - orig.length})")
    end)
  end
end