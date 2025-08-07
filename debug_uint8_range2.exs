# Debug the uint8 range error in TLV41

fixture = "test/fixtures/TLV41_DsChannelList.cm"

case File.read(fixture) do
  {:ok, binary_data} ->
    case Bindocsis.convert(binary_data, from: :binary, to: :json) do
      {:ok, json_output} ->
        data = JSON.decode!(json_output)
        tlvs = data["tlvs"]
        
        # Find TLV 41
        tlv_41 = Enum.find(tlvs, &(&1["type"] == 41))
        if tlv_41 do
          IO.puts("=== TLV 41 STRUCTURE (TRUNCATED) ===")
          IO.puts("Type: #{tlv_41["type"]}")
          IO.puts("Value type: #{tlv_41["value_type"]}")
          IO.puts("Formatted value: #{tlv_41["formatted_value"]}")
          
          # Look for the problematic value 448000000
          if Map.has_key?(tlv_41, "subtlvs") do
            IO.puts("Subtlvs count: #{length(tlv_41["subtlvs"])}")
            
            # Find subtlvs with large values
            Enum.each(tlv_41["subtlvs"], fn subtlv ->
              if is_integer(subtlv["formatted_value"]) and subtlv["formatted_value"] > 255 do
                IO.puts("\\n=== LARGE VALUE SUBTLV ===")
                IO.puts("Type: #{subtlv["type"]}")
                IO.puts("Value type: #{subtlv["value_type"]}")
                IO.puts("Formatted value: #{subtlv["formatted_value"]}")
                IO.puts("Length: #{subtlv["length"]}")
                
                # Check if it has nested subtlvs
                if Map.has_key?(subtlv, "subtlvs") and is_list(subtlv["subtlvs"]) do
                  Enum.each(subtlv["subtlvs"], fn nested ->
                    if is_integer(nested["formatted_value"]) and nested["formatted_value"] > 255 do
                      IO.puts("  Nested large value: type=#{nested["type"]}, value_type=#{nested["value_type"]}, value=#{nested["formatted_value"]}")
                    end
                  end)
                end
              end
            end)
          end
        end
      {:error, reason} ->
        IO.puts("❌ Binary -> JSON failed: #{reason}")
    end
  {:error, reason} ->
    IO.puts("❌ File read failed: #{reason}")
end