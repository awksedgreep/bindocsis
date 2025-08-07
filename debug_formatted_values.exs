#!/usr/bin/env elixir

binary = File.read!("test/fixtures/TLV_22_43_1_CMLoadBalancingPolicyID.cm")
{:ok, tlvs} = Bindocsis.parse(binary, enhanced: true)

# Function to recursively check for non-UTF8 in formatted_value
defmodule UTF8Check do
  def check_tlv(tlv, path \\ []) do
    current_path = path ++ ["TLV #{tlv.type}"]
    
    # Only check formatted_value this time
    if tlv[:formatted_value] && is_binary(tlv.formatted_value) do
      case :unicode.characters_to_binary(tlv.formatted_value, :utf8, :utf8) do
        {:error, _, _} ->
          IO.puts("❌ Invalid UTF-8 formatted_value at #{Enum.join(current_path, " -> ")}")
          IO.puts("   Value: #{inspect(tlv.formatted_value)}")
          hex = tlv.formatted_value
                |> :binary.bin_to_list()
                |> Enum.map(&Integer.to_string(&1, 16))
                |> Enum.map(&String.pad_leading(&1, 2, "0"))
                |> Enum.join(" ")
          IO.puts("   As hex: #{hex}")
        _ ->
          :ok
      end
    end
    
    # Recursively check subtlvs
    if tlv[:subtlvs] do
      Enum.each(tlv.subtlvs, fn subtlv ->
        check_tlv(subtlv, current_path)
      end)
    end
  end
end

IO.puts("Checking for non-UTF8 strings in formatted_value fields...")
Enum.each(tlvs, &UTF8Check.check_tlv/1)