#!/usr/bin/env elixir

# Debug script to understand TLV 0 issue
complex_binary = <<
  24, 12,                           # DownstreamServiceFlow (12 bytes)
  1, 2, 0, 1,                      # ServiceFlowReference 1
  6, 1, 7,                         # QoSParameterSetType 7
  7, 2, 0, 100,                    # MaxTrafficRate 100
  25, 9,                           # UpstreamServiceFlow (9 bytes)
  1, 2, 0, 2,                      # ServiceFlowReference 2
  6, 1, 7                          # QoSParameterSetType 7
>>

IO.puts("Binary data:")
IO.inspect(complex_binary, base: :hex, limit: :infinity)

IO.puts("\nParsing binary...")
{:ok, original_tlvs} = Bindocsis.parse(complex_binary, format: :binary)

IO.puts("\nParsed TLVs:")
Enum.each(original_tlvs, fn tlv ->
  IO.puts("Type: #{tlv.type}, Length: #{tlv.length}, Value: #{inspect(tlv.value, base: :hex)}")
end)

# Check if there's a TLV 0
tlv_0 = Enum.find(original_tlvs, &(&1.type == 0))
tlv_9 = Enum.find(original_tlvs, &(&1.type == 9))

if tlv_0 do
  IO.puts("\nFound TLV 0:")
  IO.inspect(tlv_0)
else
  IO.puts("\nNo TLV 0 found")
end

if tlv_9 do
  IO.puts("\nFound TLV 9:")
  IO.inspect(tlv_9)
else
  IO.puts("\nNo TLV 9 found")
end

IO.puts("\nTrying to convert to JSON...")
case Bindocsis.generate(original_tlvs, format: :json, detect_subtlvs: false) do
  {:ok, json} ->
    IO.puts("JSON conversion successful")
    IO.puts("Generated JSON:")
    IO.puts(json)
    
    IO.puts("\nTrying to parse JSON back...")
    case Bindocsis.parse(json, format: :json) do
      {:ok, parsed_back} ->
        IO.puts("JSON round-trip successful")
      {:error, reason} ->
        IO.puts("JSON parse failed: #{reason}")
    end
    
  {:error, reason} ->
    IO.puts("JSON generation failed: #{reason}")
end
