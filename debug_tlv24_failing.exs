# Debug a fixture that's actually failing with TLV 24

fixture = "test/fixtures/TLV_22_43_2_AND_3.cm"  # This one shows "TLV 24: Unsupported value type"

case File.read(fixture) do
  {:ok, binary} ->
    case Bindocsis.parse(binary, format: :binary, enhanced: true) do
      {:ok, tlvs} ->
        tlv_24 = Enum.find(tlvs, &(&1.type == 24))
        if tlv_24 do
          IO.puts("=== TLV 24 STRUCTURE (FAILING FIXTURE) ===")
          IO.puts("Type: #{inspect(tlv_24.type)}")
          IO.puts("Name: #{inspect(tlv_24.name)}")
          IO.puts("Value Type: #{inspect(tlv_24.value_type)}")
          IO.puts("Has Subtlvs: #{Map.has_key?(tlv_24, :subtlvs)}")
          if Map.has_key?(tlv_24, :subtlvs) do
            IO.puts("Subtlvs count: #{length(tlv_24.subtlvs)}")
          end
          IO.puts("Formatted Value: #{inspect(tlv_24.formatted_value)}")
        else
          IO.puts("No TLV 24 found")
        end
        
        case Bindocsis.generate(tlvs, format: :yaml) do
          {:ok, yaml} ->
            IO.puts("\n=== TLV 24 IN YAML ===")
            yaml_lines = String.split(yaml, "\n")
            tlv_24_line = Enum.find_index(yaml_lines, &String.contains?(&1, "type: 24"))
            if tlv_24_line do
              IO.puts("TLV 24 section:")
              yaml_lines 
              |> Enum.slice(tlv_24_line, 8)
              |> Enum.each(&IO.puts("  #{&1}"))
            end
            
            case Bindocsis.parse(yaml, format: :yaml) do
              {:ok, _} ->
                IO.puts("\n✓ YAML round-trip successful")
              {:error, reason} ->
                IO.puts("\n❌ YAML parse failed: #{reason}")
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