#!/usr/bin/env elixir

# Debug TLV 43 deep nesting issue
filename = "TLV_22_43_5_2_4_2_MPLSPeerIpAddress.cm"
path = "test/fixtures/#{filename}"
binary = File.read!(path)

{:ok, tlvs} = Bindocsis.parse(binary, enhanced: true)

defmodule TLVPrinter do
  def print_tree(tlv, indent \\ 0) do
    spaces = String.duplicate("  ", indent)
    formatted_val = case tlv.formatted_value do
      val when is_binary(val) and byte_size(val) > 20 -> 
        String.slice(val, 0, 20) <> "..."
      val -> inspect(val)
    end
    
    IO.puts("#{spaces}TLV #{tlv.type}: len=#{tlv.length}, type=#{tlv.value_type}, val=#{formatted_val}")
    
    subtlvs = Map.get(tlv, :subtlvs, [])
    if length(subtlvs) > 0 do
      Enum.each(subtlvs, fn subtlv ->
        print_tree(subtlv, indent + 1)
      end)
    end
  end
end

# Find TLV 22
main_tlv = Enum.find(tlvs, &(&1.type == 22))
if main_tlv do
  IO.puts("=== Original Structure ===")
  TLVPrinter.print_tree(main_tlv)
end

# Round-trip through JSON
{:ok, json_str} = Bindocsis.Generators.JsonGenerator.generate(tlvs)
{:ok, reparsed_binary} = Bindocsis.HumanConfig.from_json(json_str)
{:ok, final_tlvs} = Bindocsis.parse(reparsed_binary, enhanced: true)

final_main = Enum.find(final_tlvs, &(&1.type == 22))
if final_main do
  IO.puts("\n=== After Round-trip ===")
  TLVPrinter.print_tree(final_main)
end