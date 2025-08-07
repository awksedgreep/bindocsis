# Debug the TLV structure being passed to YAML generator

fixture = "test/fixtures/TLV_22_43_1_CMLoadBalancingPolicyID.cm"

case File.read(fixture) do
  {:ok, binary} ->
    case Bindocsis.parse(binary, format: :binary, enhanced: true) do
      {:ok, tlvs} ->
        tlv_22 = Enum.find(tlvs, &(&1.type == 22))
        IO.puts("=== TLV 22 STRUCTURE ===")
        IO.puts("Keys: #{inspect(Map.keys(tlv_22))}")
        IO.puts("Type: #{inspect(tlv_22.type)}")
        IO.puts("Value Type: #{inspect(tlv_22.value_type)}")
        IO.puts("Name: #{inspect(tlv_22.name)}")
        
        if Map.has_key?(tlv_22, :subtlvs) do
          IO.puts("Subtlvs count: #{length(tlv_22.subtlvs)}")
          first_subtlv = List.first(tlv_22.subtlvs)
          IO.puts("\nFirst subtlv structure:")
          IO.puts("Keys: #{inspect(Map.keys(first_subtlv))}")
          IO.puts("Type: #{inspect(first_subtlv.type)}")
          IO.puts("Value Type: #{inspect(Map.get(first_subtlv, :value_type))}")
          IO.puts("Name: #{inspect(Map.get(first_subtlv, :name))}")
        end
      {:error, reason} ->
        IO.puts("Binary parsing failed: #{reason}")
    end
  {:error, reason} ->
    IO.puts("File read failed: #{reason}")
end