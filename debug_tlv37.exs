# Debug TLV 37 hex dump parsing issue

fixture = "test/fixtures/TLV37_SubMgmtFilters.cm"

case File.read(fixture) do
  {:ok, binary} ->
    case Bindocsis.parse(binary, format: :binary, enhanced: true) do
      {:ok, tlvs} ->
        tlv_37 = Enum.find(tlvs, &(&1.type == 37))
        if tlv_37 do
          IO.puts("=== TLV 37 STRUCTURE ===")
          IO.puts("Type: #{inspect(tlv_37.type)}")
          IO.puts("Name: #{inspect(tlv_37.name)}")
          IO.puts("Value Type: #{inspect(tlv_37.value_type)}")
          IO.puts("Formatted Value: #{inspect(tlv_37.formatted_value)}")
          IO.puts("Has Subtlvs: #{Map.has_key?(tlv_37, :subtlvs)}")
        end
        
        case Bindocsis.generate(tlvs, format: :yaml) do
          {:ok, yaml} ->
            IO.puts("\n=== TLV 37 IN YAML ===")
            yaml_lines = String.split(yaml, "\n")
            tlv_37_line = Enum.find_index(yaml_lines, &String.contains?(&1, "type: 37"))
            if tlv_37_line do
              IO.puts("TLV 37 section:")
              yaml_lines 
              |> Enum.slice(tlv_37_line, 8)
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