# Debug TLV 22 integer format issues

# Try to find a fixture with TLV 22
fixture_files = [
  "test/fixtures/TLV_22_43_5_2_2_ServiceMultiplexingValueIEEE8021Q.cm",
  "test/fixtures/TLV_22_43_5_2_3_ServiceMultiplexingValueIEEE8021ad.cm",
  "test/fixtures/BaseConfig.cm"
]

fixture_path = Enum.find(fixture_files, &File.exists?/1)

if fixture_path do
  IO.puts("=== TLV 22 DEBUG ===")
  IO.puts("Using fixture: #{fixture_path}")

  # Parse the fixture
  case Bindocsis.parse_file(fixture_path, enhanced: true) do
    {:ok, tlvs} ->
      # Find TLV 22
      tlv_22_list = Enum.filter(tlvs, fn tlv -> tlv.type == 22 end)
      IO.puts("Found #{length(tlv_22_list)} TLV 22(s)")

      if length(tlv_22_list) > 0 do
        tlv_22 = List.first(tlv_22_list)
        IO.puts("\nTLV 22 details:")
        IO.puts("- type: #{tlv_22.type}")
        IO.puts("- length: #{tlv_22.length}")
        IO.puts("- value_type: #{inspect(tlv_22.value_type)}")
        IO.puts("- formatted_value: #{inspect(tlv_22.formatted_value)}")
        IO.puts("- raw_value: #{inspect(Map.get(tlv_22, :raw_value))}")
        IO.puts("- value: #{inspect(tlv_22.value)}")
        IO.puts("- name: #{inspect(Map.get(tlv_22, :name))}")
        IO.puts("- description: #{inspect(Map.get(tlv_22, :description))}")
        
        # Test JSON conversion
        IO.puts("\n=== JSON CONVERSION TEST ===")
        case Bindocsis.generate(tlvs, format: :json) do
          {:ok, json} -> 
            IO.puts("JSON generation successful")
            
            # Try parsing back
            case Bindocsis.parse(json, format: :json) do
              {:ok, _parsed} -> IO.puts("JSON parsing successful")
              {:error, reason} -> IO.puts("JSON parsing failed: #{reason}")
            end
            
          {:error, reason} -> 
            IO.puts("JSON generation failed: #{reason}")
        end
      else
        IO.puts("No TLV 22 found")
        IO.puts("Available TLV types: #{tlvs |> Enum.map(& &1.type) |> Enum.uniq() |> Enum.sort()}")
      end
      
    {:error, reason} ->
      IO.puts("Failed to parse fixture: #{reason}")
  end
else
  IO.puts("No suitable fixture file found")
end
EOF < /dev/null