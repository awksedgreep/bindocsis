# Show the full YAML content to see the issue

fixture = "test/fixtures/TLV_22_43_1_CMLoadBalancingPolicyID.cm"

case File.read(fixture) do
  {:ok, binary} ->
    case Bindocsis.parse(binary, format: :binary, enhanced: true) do
      {:ok, tlvs} ->
        case Bindocsis.generate(tlvs, format: :yaml) do
          {:ok, yaml} ->
            IO.puts("=== GENERATED YAML ===")
            IO.puts(yaml)
          {:error, reason} ->
            IO.puts("YAML generation failed: #{reason}")
        end
      {:error, reason} ->
        IO.puts("Binary parsing failed: #{reason}")
    end
  {:error, reason} ->
    IO.puts("File read failed: #{reason}")
end