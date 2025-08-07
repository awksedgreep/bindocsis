# Comprehensive TLV 22 debugging script
# Debug TLV 22: "Invalid integer format" issue - should be compound, not integer

IO.puts("=== TLV 22 COMPREHENSIVE DEBUG ===")

# Target fixture file
fixture_path = "test/fixtures/TLV_22_43_1_CMLoadBalancingPolicyID.cm"

if File.exists?(fixture_path) do
  IO.puts("Using fixture: #{fixture_path}")
  
  # Step 1: Parse the fixture with enhanced info
  IO.puts("\n=== STEP 1: PARSE FIXTURE ===")
  case Bindocsis.parse_file(fixture_path, enhanced: true) do
    {:ok, tlvs} ->
      IO.puts("✓ Successfully parsed #{length(tlvs)} TLVs")
      
      # Find all TLV 22s
      tlv_22_list = Enum.filter(tlvs, fn tlv -> tlv.type == 22 end)
      IO.puts("Found #{length(tlv_22_list)} TLV 22(s)")
      
      if length(tlv_22_list) > 0 do
        tlv_22 = List.first(tlv_22_list)
        
        IO.puts("\n=== STEP 2: TLV 22 STRUCTURE ANALYSIS ===")
        IO.puts("Type: #{tlv_22.type}")
        IO.puts("Length: #{tlv_22.length}")
        IO.puts("Value Type: #{inspect(tlv_22.value_type)}")
        IO.puts("Formatted Value: #{inspect(tlv_22.formatted_value)}")
        IO.puts("Raw Value: #{inspect(Map.get(tlv_22, :raw_value))}")
        IO.puts("Value: #{inspect(tlv_22.value)}")
        IO.puts("Name: #{inspect(Map.get(tlv_22, :name))}")
        IO.puts("Description: #{inspect(Map.get(tlv_22, :description))}")
        IO.puts("Has Sub-TLVs: #{inspect(Map.has_key?(tlv_22, :sub_tlvs))}")
        if Map.has_key?(tlv_22, :sub_tlvs) do
          IO.puts("Sub-TLVs: #{inspect(tlv_22.sub_tlvs)}")
        end
        
        # Check what the spec says TLV 22 should be
        IO.puts("\n=== STEP 3: SPEC VERIFICATION ===")
        spec = Bindocsis.DocsisSpecs.get_spec(22)
        IO.puts("Spec for TLV 22:")
        IO.puts("- Name: #{inspect(spec[:name])}")
        IO.puts("- Value Type: #{inspect(spec[:value_type])}")
        IO.puts("- SubTLV Support: #{inspect(spec[:sub_tlv_support])}")
        
        # Step 4: Test JSON conversion
        IO.puts("\n=== STEP 4: JSON CONVERSION TEST ===")
        case Bindocsis.generate(tlvs, format: :json) do
          {:ok, json} -> 
            IO.puts("✓ JSON generation successful")
            IO.puts("JSON preview (first 500 chars):")
            IO.puts(String.slice(json, 0, 500) <> "...")
            
            # Step 5: Test round-trip conversion
            IO.puts("\n=== STEP 5: ROUND-TRIP CONVERSION TEST ===")
            case Bindocsis.parse(json, format: :json) do
              {:ok, parsed_tlvs} -> 
                IO.puts("✓ JSON parsing successful")
                
                # Find TLV 22 in parsed data
                parsed_tlv_22_list = Enum.filter(parsed_tlvs, fn tlv -> tlv.type == 22 end)
                if length(parsed_tlv_22_list) > 0 do
                  parsed_tlv_22 = List.first(parsed_tlv_22_list)
                  IO.puts("\nParsed TLV 22 structure:")
                  IO.puts("- Type: #{parsed_tlv_22.type}")
                  IO.puts("- Length: #{parsed_tlv_22.length}")
                  IO.puts("- Value Type: #{inspect(parsed_tlv_22.value_type)}")
                  IO.puts("- Formatted Value: #{inspect(parsed_tlv_22.formatted_value)}")
                  IO.puts("- Name: #{inspect(Map.get(parsed_tlv_22, :name))}")
                  
                  # Compare original vs parsed
                  IO.puts("\n=== STEP 6: COMPARISON ===")
                  IO.puts("Original value_type: #{inspect(tlv_22.value_type)}")
                  IO.puts("Parsed value_type: #{inspect(parsed_tlv_22.value_type)}")
                  IO.puts("Original formatted_value: #{inspect(tlv_22.formatted_value)}")
                  IO.puts("Parsed formatted_value: #{inspect(parsed_tlv_22.formatted_value)}")
                  
                  if tlv_22.value_type != parsed_tlv_22.value_type do
                    IO.puts("❌ VALUE TYPE MISMATCH!")
                  else
                    IO.puts("✓ Value types match")
                  end
                  
                  # Step 7: Try to convert back to binary
                  IO.puts("\n=== STEP 7: BINARY CONVERSION TEST ===")
                  case Bindocsis.generate(parsed_tlvs, format: :binary) do
                    {:ok, _binary} ->
                      IO.puts("✓ Binary generation from parsed JSON successful")
                    {:error, reason} ->
                      IO.puts("❌ Binary generation failed: #{reason}")
                      IO.puts("This is likely where the 'Invalid integer format' error occurs")
                  end
                end
              {:error, reason} -> 
                IO.puts("❌ JSON parsing failed: #{reason}")
            end
            
          {:error, reason} -> 
            IO.puts("❌ JSON generation failed: #{reason}")
        end
        
        # Step 8: Debug raw binary data
        IO.puts("\n=== STEP 8: RAW BINARY ANALYSIS ===")
        if Map.has_key?(tlv_22, :raw_value) and tlv_22.raw_value do
          raw_bytes = tlv_22.raw_value
          IO.puts("Raw value length: #{byte_size(raw_bytes)} bytes")
          IO.puts("Raw value hex: #{Base.encode16(raw_bytes)}")
          
          # Try to parse as compound manually
          if byte_size(raw_bytes) >= 3 do
            <<sub_type, sub_length, sub_data::binary>> = raw_bytes
            IO.puts("First sub-TLV: type=#{sub_type}, length=#{sub_length}")
            if byte_size(sub_data) >= sub_length do
              remaining = binary_part(sub_data, sub_length, byte_size(sub_data) - sub_length)
              IO.puts("Remaining data after first sub-TLV: #{byte_size(remaining)} bytes")
            end
          end
        end
        
      else
        IO.puts("❌ No TLV 22 found in fixture")
        available_types = tlvs |> Enum.map(& &1.type) |> Enum.uniq() |> Enum.sort()
        IO.puts("Available TLV types: #{inspect(available_types)}")
      end
      
    {:error, reason} ->
      IO.puts("❌ Failed to parse fixture: #{reason}")
  end
else
  IO.puts("❌ Fixture file not found: #{fixture_path}")
end