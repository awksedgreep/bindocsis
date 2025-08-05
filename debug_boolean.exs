#!/usr/bin/env elixir

# Debug boolean TLV processing - test the exact scenario from the failing test
complex_binary = <<
  24, 12,                           # DownstreamServiceFlow (12 bytes)
  1, 2, 0, 1,                      # ServiceFlowReference 1
  6, 1, 7,                         # QoSParameterSetType 7
  7, 2, 0, 100,                    # MaxTrafficRate 100
  25, 9,                           # UpstreamServiceFlow (9 bytes)
  1, 2, 0, 2,                      # ServiceFlowReference 2
  6, 1, 7                          # QoSParameterSetType 7
>>

IO.puts("Parsing original binary...")
{:ok, original_tlvs} = Bindocsis.parse(complex_binary, format: :binary)

IO.puts("Original TLVs: #{inspect(Enum.map(original_tlvs, &{&1.type, Map.get(&1, :value_type)}))}")

# Test JSON conversion
IO.puts("\nTesting JSON conversion...")
case Bindocsis.generate(original_tlvs, [format: :json, detect_subtlvs: false]) do
  {:ok, json_content} ->
    IO.puts("JSON conversion successful")
    IO.puts("Generated JSON content:")
    IO.puts(json_content)
    
    # Parse the JSON to see the structure
    {:ok, decoded_json} = JSON.decode(json_content) 
    IO.puts("\nDecoded JSON structure:")
    tlv0 = Enum.find(decoded_json["tlvs"], &(&1["type"] == 0))
    if tlv0 do
      IO.puts("TLV 0 in JSON: #{inspect(tlv0)}")
      IO.puts("Value field type: #{tlv0["value"] |> :erlang.term_to_binary() |> byte_size()}-byte term, value: #{inspect(tlv0["value"])}")
      IO.puts("Formatted value: #{inspect(tlv0["formatted_value"])}")
    end
    
    IO.puts("\nParsing JSON back...")
    case Bindocsis.parse(json_content, format: :json) do
      {:ok, json_tlvs} ->
        IO.puts("JSON parsing successful")
        IO.puts("JSON TLVs: #{inspect(Enum.map(json_tlvs, &{&1.type, Map.get(&1, :value_type)}))}")
      {:error, reason} ->
        IO.puts("JSON parsing failed: #{reason}")
    end
  {:error, reason} ->
    IO.puts("JSON conversion failed: #{reason}")
end