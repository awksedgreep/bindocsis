# Debug TLV 22 YAML round-trip issue
# This is where "Invalid integer format" actually occurs

IO.puts("=== TLV 22 YAML ROUND-TRIP DEBUG ===")

fixture_path = "test/fixtures/TLV_22_43_1_CMLoadBalancingPolicyID.cm"

if File.exists?(fixture_path) do
  IO.puts("Using fixture: #{fixture_path}")

  # Step 1: Parse original binary and convert to YAML
  IO.puts("\n=== STEP 1: BINARY -> YAML ===")
  case Bindocsis.parse_file(fixture_path, enhanced: true) do
    {:ok, original_tlvs} ->
      tlv_22 = Enum.find(original_tlvs, &(&1.type == 22))
      IO.puts("✓ Original TLV 22 parsed as: #{inspect(tlv_22.value_type)}")
      IO.puts("  Formatted value: #{inspect(tlv_22.formatted_value)}")

      # Generate YAML
      case Bindocsis.generate(original_tlvs, format: :yaml) do
        {:ok, yaml_content} ->
          IO.puts("✓ YAML generation successful")
          
          # Let's inspect the YAML content for TLV 22
          IO.puts("\n=== STEP 2: YAML CONTENT INSPECTION ===")
          yaml_lines = String.split(yaml_content, "\n")
          
          # Find lines related to TLV 22
          tlv_22_section = Enum.with_index(yaml_lines)
          |> Enum.filter(fn {line, _idx} -> 
            String.contains?(line, "type: 22") or 
            String.contains?(line, "Downstream Packet Classification") or
            (String.contains?(line, "formatted_value:") and String.contains?(line, "Compound"))
          end)
          |> Enum.each(fn {line, idx} ->
            IO.puts("Line #{idx + 1}: #{line}")
          end)
          
          # Show a broader context around TLV 22
          IO.puts("\nYAML content around TLV 22:")
          tlv_22_start = yaml_lines 
          |> Enum.with_index() 
          |> Enum.find(fn {line, _} -> String.contains?(line, "type: 22") end)
          
          if tlv_22_start do
            {_, start_idx} = tlv_22_start
            context_lines = Enum.slice(yaml_lines, max(0, start_idx - 2), 15)
            Enum.with_index(context_lines, max(0, start_idx - 1))
            |> Enum.each(fn {line, idx} ->
              marker = if idx == start_idx, do: " >>> ", else: "     "
              IO.puts("#{marker}#{idx + 1}: #{line}")
            end)
          end

          # Step 3: Try to parse the YAML back
          IO.puts("\n=== STEP 3: YAML -> BINARY PARSING ===")
          case Bindocsis.parse(yaml_content, format: :yaml) do
            {:ok, parsed_tlvs} ->
              IO.puts("✓ YAML parsing successful")
              parsed_tlv_22 = Enum.find(parsed_tlvs, &(&1.type == 22))
              if parsed_tlv_22 do
                IO.puts("✓ Parsed TLV 22 value_type: #{inspect(parsed_tlv_22.value_type)}")
                IO.puts("  Formatted value: #{inspect(parsed_tlv_22.formatted_value)}")
                
                # Compare original vs parsed
                if tlv_22.value_type != parsed_tlv_22.value_type do
                  IO.puts("❌ VALUE TYPE CHANGED!")
                  IO.puts("  Original: #{inspect(tlv_22.value_type)}")
                  IO.puts("  Parsed:   #{inspect(parsed_tlv_22.value_type)}")
                else
                  IO.puts("✓ Value types match")
                end
              else
                IO.puts("❌ TLV 22 not found in parsed YAML")
              end
            
            {:error, reason} ->
              IO.puts("❌ YAML parsing failed: #{reason}")
              
              # This is where we expect to see "TLV 22: Invalid integer format"
              if String.contains?(reason, "Invalid integer format") do
                IO.puts("\n🎯 FOUND THE ISSUE!")
                IO.puts("The YAML parsing is trying to parse TLV 22 as an integer instead of compound")
                IO.puts("This means the YAML format is not preserving the compound value_type correctly")
              end
          end

        {:error, reason} ->
          IO.puts("❌ YAML generation failed: #{reason}")
      end

    {:error, reason} ->
      IO.puts("❌ Binary parsing failed: #{reason}")
  end
else  
  IO.puts("❌ Fixture file not found: #{fixture_path}")
end