# Test practical usability - can users actually work with DOCSIS config files?

fixtures = [
  "test/fixtures/BaseConfig.cm",
  "test/fixtures/TLV41_DsChannelList.cm", 
  "test/fixtures/StaticMulticastSession.cm"
]

IO.puts("=== PRACTICAL USABILITY TEST ===")

Enum.each(fixtures, fn fixture ->
  IO.puts("\n--- Testing: #{Path.basename(fixture)} ---")
  
  case File.read(fixture) do
    {:ok, binary} ->
      # Can users parse binary DOCSIS files?
      case Bindocsis.parse(binary, format: :binary, enhanced: true) do
        {:ok, tlvs} ->
          IO.puts("✅ Binary parsing: SUCCESS (#{length(tlvs)} TLVs)")
          
          # Can users convert to JSON for inspection/editing?
          case Bindocsis.generate(tlvs, format: :json) do
            {:ok, json} ->
              IO.puts("✅ JSON generation: SUCCESS")
              
              # Can users convert to YAML for human editing?
              case Bindocsis.generate(tlvs, format: :yaml) do
                {:ok, yaml} ->
                  IO.puts("✅ YAML generation: SUCCESS")
                  
                  # Can users edit YAML and convert back?
                  case Bindocsis.parse(yaml, format: :yaml) do
                    {:ok, yaml_tlvs} ->
                      IO.puts("✅ YAML parsing: SUCCESS")
                      
                      # Can users generate final binary?
                      case Bindocsis.generate(yaml_tlvs, format: :binary) do
                        {:ok, final_binary} ->
                          original_size = byte_size(binary)
                          final_size = byte_size(final_binary)
                          IO.puts("✅ Binary generation: SUCCESS (#{original_size} -> #{final_size} bytes)")
                          
                          if original_size == final_size do
                            IO.puts("   Perfect size preservation")
                          else
                            IO.puts("   Size difference: #{final_size - original_size} bytes") 
                          end
                        {:error, reason} ->
                          IO.puts("❌ Binary generation: FAILED - #{reason}")
                      end
                    {:error, reason} ->
                      IO.puts("❌ YAML parsing: FAILED - #{reason}")
                  end
                {:error, reason} ->
                  IO.puts("❌ YAML generation: FAILED - #{reason}")
              end
            {:error, reason} ->
              IO.puts("❌ JSON generation: FAILED - #{reason}")
          end
        {:error, reason} ->
          IO.puts("❌ Binary parsing: FAILED - #{reason}")
      end
    {:error, reason} ->
      IO.puts("❌ File read: FAILED - #{reason}")
  end
end)