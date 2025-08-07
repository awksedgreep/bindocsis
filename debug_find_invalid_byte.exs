#!/usr/bin/env elixir

binary = File.read!("test/fixtures/TLV_22_43_1_CMLoadBalancingPolicyID.cm")
{:ok, tlvs} = Bindocsis.parse(binary, enhanced: true)

# Function to recursively check for non-UTF8 strings
defmodule UTF8Checker do
  def check_tlv(tlv, path \\ []) do
    current_path = path ++ ["TLV #{tlv.type}"]
    
    # Check formatted_value
    if tlv[:formatted_value] do
      check_value(tlv.formatted_value, current_path ++ ["formatted_value"])
    end
    
    # Check raw_value
    if tlv[:raw_value] do
      check_value(tlv.raw_value, current_path ++ ["raw_value"])
    end
    
    # Check name
    if tlv[:name] do
      check_value(tlv.name, current_path ++ ["name"])
    end
    
    # Check description
    if tlv[:description] do
      check_value(tlv.description, current_path ++ ["description"])
    end
    
    # Recursively check subtlvs
    if tlv[:subtlvs] do
      Enum.each(tlv.subtlvs, fn subtlv ->
        check_tlv(subtlv, current_path)
      end)
    end
  end
  
  def check_value(value, path) when is_binary(value) do
    case :unicode.characters_to_binary(value, :utf8, :utf8) do
      {:error, _, _} ->
        IO.puts("❌ Invalid UTF-8 at #{Enum.join(path, " -> ")}")
        IO.puts("   Value: #{inspect(value)}")
        hex = value
              |> :binary.bin_to_list()
              |> Enum.map(&Integer.to_string(&1, 16))
              |> Enum.map(&String.pad_leading(&1, 2, "0"))
              |> Enum.join(" ")
        IO.puts("   As hex: #{hex}")
      _ ->
        :ok
    end
  end
  
  def check_value(_, _), do: :ok
end

IO.puts("Checking for non-UTF8 strings in parsed TLVs...")
Enum.each(tlvs, &UTF8Checker.check_tlv/1)