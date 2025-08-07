#!/usr/bin/env elixir

# Debug one of the remaining failures
fixture_path = "test/fixtures/TLV_22_43_5_2_4_2_MPLSPeerIpAddress.cm"
binary_data = File.read!(fixture_path)

IO.puts("File: TLV_22_43_5_2_4_2_MPLSPeerIpAddress.cm")
IO.puts("Size: #{byte_size(binary_data)} bytes\n")

# Parse with enhancement
{:ok, tlvs} = Bindocsis.parse(binary_data, enhanced: true)

# Generate JSON
{:ok, json_str} = Bindocsis.Generators.JsonGenerator.generate(tlvs)

# Try to round-trip
case Bindocsis.HumanConfig.from_json(json_str) do
  {:ok, reparsed_binary} ->
    IO.puts("Original size: #{byte_size(binary_data)}")
    IO.puts("Reparsed size: #{byte_size(reparsed_binary)}")
    IO.puts("Size difference: #{byte_size(reparsed_binary) - byte_size(binary_data)} bytes\n")
    
    # Parse the reparsed binary
    {:ok, final_tlvs} = Bindocsis.parse(reparsed_binary, enhanced: true)
    
    # Compare TLV structures
    IO.puts("Original TLVs: #{length(tlvs)}")
    IO.puts("Final TLVs: #{length(final_tlvs)}")
    
    # Find differences
    Enum.zip(tlvs, final_tlvs)
    |> Enum.with_index()
    |> Enum.each(fn {{orig, final}, idx} ->
      if orig.type != final.type or orig.length != final.length do
        IO.puts("\nTLV #{idx} mismatch:")
        IO.puts("  Original: Type=#{orig.type}, Length=#{orig.length}")
        IO.puts("  Final: Type=#{final.type}, Length=#{final.length}")
        
        # Check subtlvs if compound
        if orig.subtlvs && final.subtlvs do
          IO.puts("  Original subtlvs: #{length(orig.subtlvs || [])}")
          IO.puts("  Final subtlvs: #{length(final.subtlvs || [])}")
        end
      end
    end)
    
  {:error, reason} ->
    IO.puts("Failed to parse JSON back to binary: #{inspect(reason)}")
end