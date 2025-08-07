# Test multiple TLV 22 fixtures to find the "Invalid integer format" error

fixtures = [
  "test/fixtures/TLV_22_43_1_CMLoadBalancingPolicyID.cm",
  "test/fixtures/TLV_22_43_5_2_2_ServiceMultiplexingValueIEEE8021Q.cm", 
  "test/fixtures/TLV_22_43_5_2_3_ServiceMultiplexingValueIEEE8021ad.cm",
  "test/fixtures/TLV_22_43_5_2_4_ServiceMultiplexingValueMPLSPW.cm",
  "test/fixtures/TLV_22_43_5_21_BGPAttribute.cm"
]

IO.puts("=== TESTING MULTIPLE TLV 22 FIXTURES FOR 'Invalid integer format' ===")

Enum.each(fixtures, fn fixture ->
  IO.puts("\n--- Testing: #{Path.basename(fixture)} ---")
  
  if File.exists?(fixture) do
    case File.read(fixture) do
      {:ok, binary} ->
        case Bindocsis.parse(binary, format: :binary, enhanced: true) do
          {:ok, tlvs} ->
            tlv_22 = Enum.find(tlvs, &(&1.type == 22))
            if tlv_22 do
              IO.puts("✓ Binary parsed, TLV 22 type: #{inspect(tlv_22.value_type)}")
            else
              IO.puts("✓ Binary parsed, no TLV 22 found")
            end
        
            case Bindocsis.generate(tlvs, format: :yaml) do
              {:ok, yaml} ->
                IO.puts("✓ YAML generated")
                
                case Bindocsis.parse(yaml, format: :yaml) do
                  {:ok, _} ->
                    IO.puts("✓ YAML parsed successfully")
                  {:error, reason} ->
                    IO.puts("❌ YAML parse failed: #{reason}")
                    if String.contains?(reason, "Invalid integer format") do
                      IO.puts("🎯 FOUND 'Invalid integer format' ERROR!")
                    end
                end
              {:error, reason} ->
                IO.puts("❌ YAML generation failed: #{reason}")
            end
          {:error, reason} ->
            IO.puts("❌ Binary parsing failed: #{reason}")
        end
      {:error, reason} ->
        IO.puts("❌ File read failed: #{reason}")
    end
  else
    IO.puts("❌ Fixture not found")
  end
end)