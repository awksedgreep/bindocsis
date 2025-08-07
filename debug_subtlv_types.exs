# Debug where subtlvs get their value types assigned

fixture = "test/fixtures/StaticMulticastSession.cm"

case File.read(fixture) do
  {:ok, binary_data} ->
    case Bindocsis.convert(binary_data, from: :binary, to: :json) do
      {:ok, json_output} ->
        data = JSON.decode!(json_output)
        tlvs = data["tlvs"]
        
        # Find TLV 64 and examine its subtlvs
        tlv_64 = Enum.find(tlvs, &(&1["type"] == 64))
        if tlv_64 && Map.has_key?(tlv_64, "subtlvs") do
          IO.puts("=== TLV 64 SUBTLVS ===")
          
          Enum.each(tlv_64["subtlvs"], fn subtlv ->
            IO.puts("SubTLV type #{subtlv["type"]}: value_type=#{subtlv["value_type"]}, formatted_value=#{inspect(subtlv["formatted_value"])}")
            
            # Check nested subtlvs too
            if Map.has_key?(subtlv, "subtlvs") and is_list(subtlv["subtlvs"]) do
              Enum.each(subtlv["subtlvs"], fn nested ->
                IO.puts("  Nested type #{nested["type"]}: value_type=#{nested["value_type"]}, formatted_value=#{inspect(nested["formatted_value"])}")
              end)
            end
          end)
        end
        
        # Look for the specific large value 337124384
        IO.puts("\\n=== SEARCHING FOR LARGE VALUE 337124384 ===")
        search_tlvs_for_value(tlvs, 337124384, [])
        
      defp search_tlvs_for_value(tlvs_list, target_value, path) do
        Enum.each(tlvs_list, fn tlv ->
          current_path = path ++ [tlv["type"]]
          
          if tlv["formatted_value"] == target_value do
            IO.puts("\\n=== FOUND LARGE VALUE #{target_value} ===")
            IO.puts("Path: #{inspect(current_path)}")
            IO.puts("Type: #{tlv["type"]}")
            IO.puts("Value type: #{tlv["value_type"]} (SHOULD BE uint32 or frequency)")
            IO.puts("Formatted value: #{tlv["formatted_value"]}")
            IO.puts("Length: #{tlv["length"]}")
          end
          
          if Map.has_key?(tlv, "subtlvs") and is_list(tlv["subtlvs"]) do
            search_tlvs_for_value(tlv["subtlvs"], target_value, current_path)
          end
        end)
      end
      {:error, reason} ->
        IO.puts("❌ Binary -> JSON failed: #{reason}")
    end
  {:error, reason} ->
    IO.puts("❌ File read failed: #{reason}")
end