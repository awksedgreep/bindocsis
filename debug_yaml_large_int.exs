#!/usr/bin/env elixir

fixture_path = "test/fixtures/TLV_22_43_5_14_DPoE.cm"
binary_data = File.read!(fixture_path)

# Parse with enhancement
{:ok, tlvs} = Bindocsis.parse(binary_data, enhanced: true)

# Generate YAML
{:ok, yaml_str} = Bindocsis.Generators.YamlGenerator.generate(tlvs, 
  include_names: true, docsis_version: "3.1")

# Write it for inspection
File.write!("/tmp/debug_dpoe.yaml", yaml_str)

# Find the problematic TLV 14
tlv22 = Enum.find(tlvs, &(&1.type == 22))
if tlv22 do
  tlv43 = Enum.find(tlv22.subtlvs || [], &(&1.type == 43))
  if tlv43 do
    tlv5 = Enum.find(tlv43.subtlvs || [], &(&1.type == 5))
    if tlv5 do
      tlv14 = Enum.find(tlv5.subtlvs || [], &(&1.type == 14))
      if tlv14 do
        IO.puts("TLV 22.43.5.14 details:")
        IO.puts("Type: #{tlv14.type}")
        IO.puts("Name: #{Map.get(tlv14, :name, "N/A")}")
        IO.puts("Length: #{tlv14.length}")
        IO.puts("Value (hex): #{Base.encode16(tlv14.value)}")
        IO.puts("Formatted value: #{inspect(tlv14.formatted_value)}")
        IO.puts("Value type: #{inspect(tlv14.value_type)}")
      end
    end
  end
end

IO.puts("\n=== Checking YAML content ===")
# Look for the problematic value in YAML
yaml_lines = String.split(yaml_str, "\n")
Enum.each(yaml_lines, fn line ->
  if String.contains?(line, "102010202020") do
    IO.puts("Found problematic line: #{line}")
  end
end)