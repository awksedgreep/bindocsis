# Debug TLV 22 YAML generation issue

fixture = "test/fixtures/TLV_22_43_1_CMLoadBalancingPolicyID.cm"

IO.puts("=== DEBUGGING TLV 22 YAML ISSUE ===")

case File.read(fixture) do
  {:ok, binary} ->
    IO.puts("✓ File read, size: #{byte_size(binary)} bytes")
    
    # Parse the binary
    case Bindocsis.parse(binary, format: :binary, enhanced: true) do
      {:ok, tlvs} ->
        tlv_22 = Enum.find(tlvs, &(&1.type == 22))
        IO.puts("Found TLV 22:")
        IO.puts("  Type: #{inspect(tlv_22.type)}")
        IO.puts("  Name: #{inspect(tlv_22.name)}")
        IO.puts("  Value Type: #{inspect(tlv_22.value_type)}")
        IO.puts("  SubTLV Support: #{inspect(Map.get(tlv_22, :subtlv_support))}")
        IO.puts("  Has Subtlvs: #{Map.has_key?(tlv_22, :subtlvs)}")
        
        # Generate YAML and see what the YAML generator produces
        case Bindocsis.generate(tlvs, format: :yaml) do
          {:ok, yaml} ->
            IO.puts("\n✓ YAML generated")
            
            # Look for the TLV 22 section in YAML
            yaml_lines = String.split(yaml, "\n")
            tlv_22_line = Enum.find_index(yaml_lines, &String.contains?(&1, "type: 22"))
            if tlv_22_line do
              IO.puts("TLV 22 in YAML (lines #{tlv_22_line}-#{tlv_22_line+5}):")
              yaml_lines 
              |> Enum.slice(tlv_22_line, 6)
              |> Enum.each(&IO.puts("  #{&1}"))
            end
            
            # Now try to parse it back
            case Bindocsis.parse(yaml, format: :yaml) do
              {:ok, _} ->
                IO.puts("\n✓ YAML round-trip successful")
              {:error, reason} ->
                IO.puts("\n❌ YAML parse failed: #{reason}")
            end
          {:error, reason} ->
            IO.puts("❌ YAML generation failed: #{reason}")
        end
      {:error, reason} ->
        IO.puts("❌ Binary parsing failed: #{reason}")
    end
  {:error, reason} ->
    IO.puts("❌ File read failed: #{reason}")
end