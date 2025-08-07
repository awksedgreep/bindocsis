# Real-world DOCSIS config editing workflow

IO.puts("=== REAL-WORLD DOCSIS CONFIG EDITING ===")

# Step 1: Parse original binary config
fixture = "test/fixtures/BaseConfig.cm"
IO.puts("\n1. Reading original config file: #{Path.basename(fixture)}")

{:ok, original_binary} = File.read(fixture)
IO.puts("   Original file size: #{byte_size(original_binary)} bytes")

# Step 2: Convert to YAML for human editing
IO.puts("\n2. Converting to YAML for editing...")
{:ok, tlvs} = Bindocsis.parse(original_binary, format: :binary, enhanced: true)
{:ok, yaml_content} = Bindocsis.generate(tlvs, format: :yaml)

# Save YAML to file for editing
yaml_file = "config_for_editing.yaml"
File.write!(yaml_file, yaml_content)
IO.puts("   Created editable YAML: #{yaml_file}")

# Step 3: Show current values that we'll edit
IO.puts("\n3. Current config values:")
yaml_lines = String.split(yaml_content, "\n")

# Find and show key configuration values
Enum.with_index(yaml_lines, 1)
|> Enum.each(fn {line, line_num} ->
  cond do
    String.contains?(line, "formatted_value:") and String.contains?(line, "1") ->
      IO.puts("   Line #{line_num}: #{String.trim(line)} <- Network Access (boolean)")
    String.contains?(line, "Downstream Frequency") ->
      IO.puts("   Line #{line_num}: #{String.trim(line)}")
    true -> nil
  end
end)

# Step 4: Edit the YAML (simulate user editing)
IO.puts("\n4. Simulating user edits...")
IO.puts("   - Changing Network Access from 1 (enabled) to 0 (disabled)")
IO.puts("   - Changing downstream frequency from 1 to 591000000 (591 MHz)")

edited_yaml = yaml_content
|> String.replace(~r/(\s+formatted_value:\s+)1(\s*# Network Access)/, "\\g{1}0\\g{2}")
|> String.replace(~r/(\s+formatted_value:\s+)1(\s*\n.*name: Downstream Frequency)/, "\\g{1}591000000\\g{2}")

# Save edited version
edited_yaml_file = "config_edited.yaml"
File.write!(edited_yaml_file, edited_yaml)
IO.puts("   Saved edited YAML: #{edited_yaml_file}")

# Step 5: Convert edited YAML back to binary
IO.puts("\n5. Converting edited YAML back to binary config...")
case Bindocsis.parse(edited_yaml, format: :yaml) do
  {:ok, edited_tlvs} ->
    case Bindocsis.generate(edited_tlvs, format: :binary) do
      {:ok, final_binary} ->
        # Save the new config file
        new_config_file = "BaseConfig_modified.cm"
        File.write!(new_config_file, final_binary)
        
        IO.puts("   ✅ SUCCESS! Created: #{new_config_file}")
        IO.puts("   Original size: #{byte_size(original_binary)} bytes")
        IO.puts("   Modified size: #{byte_size(final_binary)} bytes")
        
        # Step 6: Verify the changes took effect
        IO.puts("\n6. Verifying changes in new config...")
        {:ok, verification_tlvs} = Bindocsis.parse(final_binary, format: :binary, enhanced: true)
        {:ok, verification_json} = Bindocsis.generate(verification_tlvs, format: :json)
        
        verification_data = JSON.decode!(verification_json)
        
        # Check Network Access setting
        network_access = Enum.find(verification_data["tlvs"], &(&1["type"] == 3))
        if network_access do
          IO.puts("   Network Access (TLV 3): #{network_access["formatted_value"]} (was 1, now #{network_access["formatted_value"]})")
        end
        
        # Check downstream frequency
        Enum.each(verification_data["tlvs"], fn tlv ->
          if Map.has_key?(tlv, "subtlvs") do
            Enum.each(tlv["subtlvs"], fn subtlv ->
              if subtlv["name"] == "Downstream Frequency" do
                IO.puts("   Downstream Frequency: #{subtlv["formatted_value"]} Hz (was 1, now #{subtlv["formatted_value"]})")
              end
            end)
          end
        end)
        
        IO.puts("\n7. Files created:")
        IO.puts("   - #{yaml_file} (original config as YAML)")
        IO.puts("   - #{edited_yaml_file} (user-edited YAML)")  
        IO.puts("   - #{new_config_file} (final binary config)")
        IO.puts("\n✅ Real-world editing workflow: COMPLETE!")
        
      {:error, reason} ->
        IO.puts("   ❌ Failed to generate binary: #{reason}")
    end
  {:error, reason} ->
    IO.puts("   ❌ Failed to parse edited YAML: #{reason}")
end