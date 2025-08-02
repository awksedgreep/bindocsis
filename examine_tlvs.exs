#!/usr/bin/env elixir

# Read and parse the JSON
{:ok, json_content} = File.read("17HarvestMoonCW_editable.json")
{:ok, tlvs} = Bindocsis.parse(json_content, format: :json)

IO.puts("All TLVs in the file:")
IO.puts("===================")

tlvs
|> Enum.with_index()
|> Enum.each(fn {tlv, index} ->
  name = Map.get(tlv, :name, "Type #{tlv.type}")
  desc = Map.get(tlv, :description, "")
  
  IO.puts("#{index}: #{name} (Type #{tlv.type}, Length #{tlv.length})")
  if desc != "", do: IO.puts("    Description: #{desc}")
  
  # Show value if it's not too long
  case tlv.value do
    val when is_integer(val) -> IO.puts("    Value: #{val}")
    val when is_binary(val) and byte_size(val) <= 20 -> 
      IO.puts("    Value: #{inspect(val)}")
    _ -> nil
  end
  
  # Show subtlvs if present
  if Map.has_key?(tlv, :subtlvs) and tlv.subtlvs do
    IO.puts("    SubTLVs:")
    tlv.subtlvs 
    |> Enum.with_index()
    |> Enum.each(fn {subtlv, sub_index} ->
      sub_name = Map.get(subtlv, :name, "Type #{subtlv.type}")
      sub_desc = Map.get(subtlv, :description, "")
      IO.puts("      #{sub_index}: #{sub_name} (Type #{subtlv.type}) = #{subtlv.value}")
      if sub_desc != "", do: IO.puts("          #{sub_desc}")
    end)
  end
  
  IO.puts("")
end)