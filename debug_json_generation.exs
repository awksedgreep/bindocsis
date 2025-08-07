#!/usr/bin/env elixir

binary = File.read!("test/fixtures/TLV_22_43_1_CMLoadBalancingPolicyID.cm")
{:ok, tlvs} = Bindocsis.parse(binary, enhanced: true)

# Try to generate JSON structure
case Bindocsis.Generators.JsonGenerator.generate(tlvs, []) do
  {:ok, json_map} ->
    IO.puts("✅ JSON map generated successfully")
    
    # Find TLV 22 -> 43 -> 8
    tlv22 = Enum.find(json_map["tlvs"], fn t -> t["type"] == 22 end)
    if tlv22 && tlv22["subtlvs"] do
      tlv43 = Enum.find(tlv22["subtlvs"], fn t -> t["type"] == 43 end)
      if tlv43 && tlv43["subtlvs"] do
        tlv8 = Enum.find(tlv43["subtlvs"], fn t -> t["type"] == 8 end)
        if tlv8 do
          IO.puts("\nTLV 43.8 in JSON map:")
          IO.inspect(tlv8, limit: :infinity)
          
          # Check if formatted_value is a valid UTF-8 string
          fv = tlv8["formatted_value"]
          if is_binary(fv) do
            IO.puts("\nformatted_value is binary: #{inspect(fv)}")
            case :unicode.characters_to_binary(fv, :utf8, :utf8) do
              {:error, _, _} ->
                IO.puts("❌ NOT valid UTF-8!")
              _ ->
                IO.puts("✅ Valid UTF-8")
            end
          end
        end
      end
    end
    
    # Now try to encode as JSON
    IO.puts("\nTrying to encode as JSON...")
    case JSON.encode(json_map) do
      {:ok, _json_string} ->
        IO.puts("✅ JSON encoding successful")
      {:error, error} ->
        IO.puts("❌ JSON encoding failed: #{inspect(error)}")
    end
    
  {:error, reason} ->
    IO.puts("❌ JSON map generation failed: #{reason}")
end