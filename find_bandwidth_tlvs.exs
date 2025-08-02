#!/usr/bin/env elixir

# Read and parse the JSON
{:ok, json_content} = File.read("17HarvestMoonCW_editable.json")
{:ok, tlvs} = Bindocsis.parse(json_content, format: :json) 

IO.puts("=== SEARCHING FOR BANDWIDTH-RELATED TLVs ===")
IO.puts("")

# Let's specifically look for service flow related TLVs
tlvs
|> Enum.with_index()
|> Enum.each(fn {tlv, index} ->
  cond do
    # Service Flow TLVs (types 22-25)
    tlv.type in [22, 23, 24, 25] ->
      IO.puts("🔍 SERVICE FLOW TLV #{index}: Type #{tlv.type} (Length: #{tlv.length})")
      
      if Map.has_key?(tlv, :subtlvs) and tlv.subtlvs do
        IO.puts("  SubTLVs:")
        tlv.subtlvs
        |> Enum.with_index()
        |> Enum.each(fn {subtlv, sub_index} ->
          name = Map.get(subtlv, :name, "Unknown")
          desc = Map.get(subtlv, :description, "")
          IO.puts("    #{sub_index}: Type #{subtlv.type} - #{name}")
          IO.puts("        Value: #{subtlv.value}")
          if desc != "", do: IO.puts("        Description: #{desc}")
        end)
      else
        case tlv.value do
          val when is_binary(val) and byte_size(val) <= 30 ->
            IO.puts("  Direct value: #{inspect(val)}")
          val when is_integer(val) ->
            IO.puts("  Direct value: #{val}")
          _ ->
            IO.puts("  Large binary value (#{byte_size(tlv.value)} bytes)")
        end
      end
      IO.puts("")
    
    # Look for any TLV that might contain bandwidth values (large numbers)
    is_integer(tlv.value) and tlv.value > 1000000 ->
      IO.puts("🚀 LARGE VALUE TLV #{index}: Type #{tlv.type} = #{tlv.value}")
      name = Map.get(tlv, :name, "Unknown")
      desc = Map.get(tlv, :description, "")
      IO.puts("   Name: #{name}")
      if desc != "", do: IO.puts("   Description: #{desc}")
      IO.puts("")
    
    # Check subtlvs for large values too
    Map.has_key?(tlv, :subtlvs) and tlv.subtlvs ->
      large_subtlvs = tlv.subtlvs
      |> Enum.with_index()
      |> Enum.filter(fn {subtlv, _} -> is_integer(subtlv.value) and subtlv.value > 1000000 end)
      
      if length(large_subtlvs) > 0 do
        IO.puts("🎯 TLV #{index} (Type #{tlv.type}) has large SubTLVs:")
        large_subtlvs
        |> Enum.each(fn {subtlv, sub_index} ->
          name = Map.get(subtlv, :name, "Unknown")
          IO.puts("    SubTLV #{sub_index}: Type #{subtlv.type} - #{name} = #{subtlv.value}")
        end)
        IO.puts("")
      end
    
    true -> nil
  end
end)