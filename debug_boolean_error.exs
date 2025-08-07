# Debug boolean value error

defp find_boolean_subtlvs(subtlvs, path) when is_list(subtlvs) do
  Enum.each(subtlvs, fn subtlv ->
    current_path = path ++ [subtlv["type"]]
    
    if subtlv["value_type"] == "boolean" do
      IO.puts("Boolean SubTLV at path #{inspect(current_path)}:")
      IO.puts("  formatted_value: #{inspect(subtlv["formatted_value"])}")
      IO.puts("  value_type: #{inspect(subtlv["value_type"])}")
    end
    
    if Map.has_key?(subtlv, "subtlvs") and is_list(subtlv["subtlvs"]) do
      find_boolean_subtlvs(subtlv["subtlvs"], current_path)
    end
  end)
end

fixture = "test/fixtures/TLV_24_last_before_43.cm"

case File.read(fixture) do
  {:ok, binary_data} ->
    case Bindocsis.convert(binary_data, from: :binary, to: :json) do
      {:ok, json_output} ->
        IO.puts("=== JSON GENERATED ===")
        data = JSON.decode!(json_output)
        tlvs = data["tlvs"]
        
        # Find TLV 24
        tlv_24 = Enum.find(tlvs, &(&1["type"] == 24))
        if tlv_24 do
          IO.puts("TLV 24 structure:")
          IO.inspect(tlv_24, pretty: true)
          
          # Look for boolean subtlvs
          if Map.has_key?(tlv_24, "subtlvs") do
            IO.puts("\n=== SUBTLVS WITH BOOLEAN ISSUES ===")
            find_boolean_subtlvs(tlv_24["subtlvs"], [24])
          end
        end
        
        # Try converting back to see the exact error
        case Bindocsis.convert(json_output, from: :json, to: :binary) do
          {:ok, _} ->
            IO.puts("✓ JSON -> Binary conversion succeeded")
          {:error, reason} ->
            IO.puts("\n❌ JSON -> Binary conversion failed:")
            IO.puts(reason)
        end
      {:error, reason} ->
        IO.puts("❌ Binary -> JSON failed: #{reason}")
    end
  {:error, reason} ->
    IO.puts("❌ File read failed: #{reason}")
end