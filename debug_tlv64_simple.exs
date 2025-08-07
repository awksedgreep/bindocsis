# Debug TLV 64 structure in StaticMulticastSession.cm

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
        else
          IO.puts("TLV 64 not found")
        end
      {:error, reason} ->
        IO.puts("❌ Binary -> JSON failed: #{reason}")
    end
  {:error, reason} ->
    IO.puts("❌ File read failed: #{reason}")
end