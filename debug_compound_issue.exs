#!/usr/bin/env elixir

# Debug script to understand the compound TLV issue

binary = File.read!("test/fixtures/BaseConfig.cm")
{:ok, tlvs} = Bindocsis.parse(binary, enhanced: true)

# Find TLV 24 (Downstream Service Flow)
tlv24 = Enum.find(tlvs, fn t -> t.type == 24 end)

if tlv24 do
  IO.puts("=== TLV 24 (Downstream Service Flow) ===")
  IO.puts("value_type: #{tlv24.value_type}")
  IO.puts("formatted_value: #{inspect(tlv24.formatted_value)}")
  
  if Map.has_key?(tlv24, :subtlvs) and is_list(tlv24.subtlvs) do
    IO.puts("\nSubTLVs:")
    Enum.each(tlv24.subtlvs, fn subtlv ->
      IO.puts("  SubTLV #{subtlv.type} (#{subtlv.name}):")
      IO.puts("    value_type: #{subtlv.value_type}")
      IO.puts("    value size: #{byte_size(subtlv.value)} bytes")
      IO.puts("    formatted_value: #{inspect(subtlv.formatted_value)}")
    end)
  end
end

# Now test JSON generation to see what gets generated
IO.puts("\n=== JSON Generation Test ===")
case Bindocsis.HumanConfig.to_json(binary) do
  {:ok, json_content} ->
    IO.puts("JSON generated successfully")
    
    # Parse JSON and look at TLV 24's subtlvs
    {:ok, parsed} = JSON.decode(json_content)
    tlvs = Map.get(parsed, "tlvs", [])
    tlv24_json = Enum.find(tlvs, fn t -> t["type"] == 24 end)
    
    if tlv24_json && tlv24_json["subtlvs"] do
      IO.puts("\nTLV 24 subtlvs in JSON:")
      Enum.each(tlv24_json["subtlvs"], fn subtlv ->
        IO.puts("  SubTLV #{subtlv["type"]}:")
        IO.puts("    formatted_value: #{inspect(subtlv["formatted_value"])}")
        IO.puts("    value_type: #{subtlv["value_type"]}")
      end)
    end
    
  {:error, error} ->
    IO.puts("JSON generation failed: #{error}")
end