# Debug frequency format error

fixture = "test/fixtures/TLV_22_43_5_2_1.cm"

case File.read(fixture) do
  {:ok, binary_data} ->
    case Bindocsis.convert(binary_data, from: :binary, to: :json) do
      {:ok, json_output} ->
        IO.puts("✓ Binary -> JSON succeeded")
        
        # Look for frequency values in the JSON
        data = JSON.decode!(json_output)
        find_frequency_values(data["tlvs"], [])
        
        case Bindocsis.convert(json_output, from: :json, to: :binary) do
          {:ok, _} ->
            IO.puts("✅ JSON -> Binary succeeded")
          {:error, reason} ->
            IO.puts("❌ JSON -> Binary failed: #{reason}")
        end
      {:error, reason} ->
        IO.puts("❌ Binary -> JSON failed: #{reason}")
    end
  {:error, reason} ->
    IO.puts("❌ File read failed: #{reason}")
end

defp find_frequency_values(tlvs, path) when is_list(tlvs) do
  Enum.each(tlvs, fn tlv ->
    current_path = path ++ [tlv["type"]]
    
    if tlv["value_type"] == "frequency" do
      IO.puts("\\nFrequency TLV at path #{inspect(current_path)}:")
      IO.puts("  Type: #{tlv["type"]}")
      IO.puts("  Value type: #{tlv["value_type"]}")
      IO.puts("  Formatted value: #{inspect(tlv["formatted_value"])}")
      IO.puts("  Length: #{tlv["length"]}")
    end
    
    if Map.has_key?(tlv, "subtlvs") and is_list(tlv["subtlvs"]) do
      find_frequency_values(tlv["subtlvs"], current_path)
    end
  end)
end