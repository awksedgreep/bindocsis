# Debug the uint8 range error

fixture = "test/fixtures/StaticMulticastSession.cm"

case File.read(fixture) do
  {:ok, binary_data} ->
    case Bindocsis.convert(binary_data, from: :binary, to: :json) do
      {:ok, json_output} ->
        data = JSON.decode!(json_output)
        tlvs = data["tlvs"]
        
        # Find TLV 64
        tlv_64 = Enum.find(tlvs, &(&1["type"] == 64))
        if tlv_64 do
          IO.puts("=== TLV 64 STRUCTURE ===")
          IO.inspect(tlv_64, pretty: true, limit: :infinity)
          
          # Look for the problematic value 337124384
          if Map.has_key?(tlv_64, "subtlvs") do
            Enum.each(tlv_64["subtlvs"], fn subtlv ->
              if subtlv["formatted_value"] == 337124384 do
                IO.puts("\n=== PROBLEMATIC SUBTLV ===")
                IO.puts("Type: #{subtlv["type"]}")
                IO.puts("Value type: #{subtlv["value_type"]} (should probably be uint32)")
                IO.puts("Formatted value: #{subtlv["formatted_value"]}")
                IO.puts("Length: #{subtlv["length"]}")
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