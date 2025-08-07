# Check if value_type is in the YAML

fixture = "test/fixtures/TLV_22_43_1_CMLoadBalancingPolicyID.cm"

case File.read(fixture) do
  {:ok, binary} ->
    case Bindocsis.parse(binary, format: :binary, enhanced: true) do
      {:ok, tlvs} ->
        case Bindocsis.generate(tlvs, format: :yaml) do
          {:ok, yaml} ->
            IO.puts("=== CHECKING FOR value_type IN YAML ===")
            
            # Check if "value_type" appears in the YAML
            if String.contains?(yaml, "value_type") do
              IO.puts("✓ Found value_type in YAML")
              
              # Find all lines with value_type
              yaml_lines = String.split(yaml, "\n")
              value_type_lines = Enum.with_index(yaml_lines)
                               |> Enum.filter(fn {line, _idx} -> String.contains?(line, "value_type") end)
                               |> Enum.map(fn {line, idx} -> "Line #{idx + 1}: #{line}" end)
              
              IO.puts("Value type lines:")
              Enum.each(value_type_lines, &IO.puts("  #{&1}"))
            else
              IO.puts("❌ No value_type found in YAML")
            end
            
            # Also check for compound references
            if String.contains?(yaml, "compound") do
              IO.puts("✓ Found 'compound' references in YAML")
            else
              IO.puts("❌ No 'compound' references found in YAML")
            end
          {:error, reason} ->
            IO.puts("YAML generation failed: #{reason}")
        end
      {:error, reason} ->
        IO.puts("Binary parsing failed: #{reason}")
    end
  {:error, reason} ->
    IO.puts("File read failed: #{reason}")
end