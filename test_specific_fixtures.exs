# Test specific fixtures to see if our fixes are working

fixtures = [
  "test/fixtures/TLV_22_43_1_CMLoadBalancingPolicyID.cm",  # Original test case
  "test/fixtures/TLV_22_43_2_AND_3.cm",                   # TLV 24 error reported
  "test/fixtures/BaseConfig.cm"                           # TLV 24 error reported
]

IO.puts("=== TESTING SPECIFIC FIXTURES ===")

Enum.each(fixtures, fn fixture ->
  IO.puts("\n--- Testing: #{Path.basename(fixture)} ---")
  
  case File.read(fixture) do
    {:ok, binary} ->
      case Bindocsis.parse(binary, format: :binary, enhanced: true) do
        {:ok, tlvs} ->
          IO.puts("✓ Binary parsed successfully")
          
          case Bindocsis.generate(tlvs, format: :yaml) do
            {:ok, yaml} ->
              IO.puts("✓ YAML generated successfully")
              
              case Bindocsis.parse(yaml, format: :yaml) do
                {:ok, _} ->
                  IO.puts("✅ YAML round-trip SUCCESSFUL")
                {:error, reason} ->
                  IO.puts("❌ YAML round-trip FAILED: #{reason}")
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
end)