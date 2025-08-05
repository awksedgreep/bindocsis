#!/usr/bin/env elixir

# Test the specific issue with TLV 43 integer format
fixture_path = "test/fixtures/simple_edge_case.cm"

IO.puts("Testing TLV 43 integer format issue...")

# Step 1: Parse the binary file
case Bindocsis.parse_file(fixture_path) do
  {:ok, tlvs} ->
    IO.puts("Successfully parsed #{length(tlvs)} TLVs from binary file")
    
    # Find TLV 43 in the original parse
    tlv43 = Enum.find(tlvs, &(&1.type == 43))
    if tlv43 do
      IO.puts("Found TLV 43 in original:")
      IO.puts("  Type: #{tlv43.type}")
      IO.puts("  Length: #{tlv43.length}")
      IO.puts("  Value: #{inspect(tlv43.value)}")
      IO.puts("  Value type: #{Map.get(tlv43, :value_type)}")
      IO.puts("  Formatted value: #{Map.get(tlv43, :formatted_value)}")
    else
      IO.puts("No TLV 43 found in original parse")
    end
    
    # Step 2: Generate pretty JSON
    case Bindocsis.generate(tlvs, format: :json, pretty: true) do
      {:ok, pretty_json} ->
        IO.puts("\nSuccessfully generated pretty JSON")
        
        # Extract just the TLV 43 portion from the JSON
        if String.contains?(pretty_json, "\"type\": 43") do
          IO.puts("\nTLV 43 portion in JSON:")
          # Find lines around TLV 43
          lines = String.split(pretty_json, "\n")
          tlv43_line_index = Enum.find_index(lines, &String.contains?(&1, "\"type\": 43"))
          if tlv43_line_index do
            start_index = max(0, tlv43_line_index - 2)
            end_index = min(length(lines), tlv43_line_index + 8)
            relevant_lines = Enum.slice(lines, start_index, end_index - start_index)
            Enum.each(relevant_lines, &IO.puts("  #{&1}"))
          end
        else
          IO.puts("TLV 43 not found in JSON")
        end
        
        # Step 3: Try to parse the pretty JSON back
        IO.puts("\nAttempting to parse pretty JSON back...")
        case Bindocsis.parse(pretty_json, format: :json) do
          {:ok, json_tlvs} ->
            IO.puts("Successfully parsed JSON back to #{length(json_tlvs)} TLVs")
          {:error, reason} ->
            IO.puts("ERROR parsing JSON back: #{reason}")
        end
        
      {:error, reason} ->
        IO.puts("ERROR generating pretty JSON: #{reason}")
    end
    
  {:error, reason} ->
    IO.puts("ERROR parsing binary file: #{reason}")
end
