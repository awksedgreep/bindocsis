# Debug the boolean issue in TLV41

fixture = "test/fixtures/TLV41_DsChannelList.cm"

case File.read(fixture) do
  {:ok, binary_data} ->
    case Bindocsis.convert(binary_data, from: :binary, to: :json) do
      {:ok, json_output} ->
        # Parse and find all boolean value types
        data = JSON.decode!(json_output)
        
        find_booleans = fn tlvs, path ->
          Enum.each(tlvs, fn tlv ->
            current_path = path ++ [tlv["type"]]
            
            if tlv["value_type"] == "boolean" do
              IO.puts("Boolean TLV at #{inspect(current_path)}:")
              IO.puts("  formatted_value: #{inspect(tlv["formatted_value"])}")
              IO.puts("  length: #{tlv["length"]}")
              
              # Test if this specific boolean value parses
              IO.puts("  Direct parse test:")
              result = Bindocsis.ValueParser.parse_value("boolean", tlv["formatted_value"], [])
              IO.puts("  Result: #{inspect(result)}")
            end
            
            if Map.has_key?(tlv, "subtlvs") and is_list(tlv["subtlvs"]) do
              find_booleans.(tlv["subtlvs"], current_path)
            end
          end)
        end
        
        find_booleans.(data["tlvs"], [])
        
      {:error, reason} ->
        IO.puts("❌ Binary -> JSON failed: #{reason}")
    end
  {:error, reason} ->
    IO.puts("❌ File read failed: #{reason}")
end