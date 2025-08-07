# Test a single failing fixture to understand and fix it

fixture = "test/fixtures/TLV_22_43_1_CMLoadBalancingPolicyID.cm"

IO.puts("=== TESTING SINGLE FIXTURE ===")
IO.puts("Fixture: #{Path.basename(fixture)}")

case File.read(fixture) do
  {:ok, binary_data} ->
    IO.puts("✓ File read successfully")
    
    case Bindocsis.convert(binary_data, from: :binary, to: :json) do
      {:ok, json_output} ->
        IO.puts("✓ Binary -> JSON conversion succeeded")
        
        case Bindocsis.convert(json_output, from: :json, to: :binary) do
          {:ok, _roundtrip_binary} ->
            IO.puts("✅ JSON -> Binary round-trip SUCCESSFUL")
          {:error, reason} ->
            IO.puts("❌ JSON -> Binary conversion failed:")
            IO.puts(reason)
            
            # Let's examine the JSON structure to understand the issue
            IO.puts("\n=== JSON STRUCTURE ANALYSIS ===")
            data = JSON.decode!(json_output)
            tlvs = data["tlvs"]
            IO.puts("Total TLVs: #{length(tlvs)}")
            
            # Find TLV 22 (the failing one based on error message)
            tlv_22 = Enum.find(tlvs, &(&1["type"] == 22))
            if tlv_22 do
              IO.puts("\nTLV 22 structure:")
              IO.puts("  Type: #{tlv_22["type"]}")
              IO.puts("  Value type: #{tlv_22["value_type"]}")
              IO.puts("  Formatted value: #{inspect(tlv_22["formatted_value"])}")
              IO.puts("  Has subtlvs: #{Map.has_key?(tlv_22, "subtlvs")}")
              
              if Map.has_key?(tlv_22, "subtlvs") and is_list(tlv_22["subtlvs"]) do
                IO.puts("  Subtlvs count: #{length(tlv_22["subtlvs"])}")
                
                # Show first few subtlvs
                Enum.take(tlv_22["subtlvs"], 3)
                |> Enum.with_index()
                |> Enum.each(fn {subtlv, i} ->
                  IO.puts("  SubTLV #{i+1}: type=#{subtlv["type"]}, value_type=#{subtlv["value_type"]}, formatted_value=#{inspect(subtlv["formatted_value"])}")
                end)
              end
            else
              IO.puts("No TLV 22 found")
            end
        end
      {:error, reason} ->
        IO.puts("❌ Binary -> JSON conversion failed: #{reason}")
    end
  {:error, reason} ->
    IO.puts("❌ File read failed: #{reason}")
end