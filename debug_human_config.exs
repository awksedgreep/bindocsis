#!/usr/bin/env elixir

binary = File.read!("test/fixtures/TLV_22_43_1_CMLoadBalancingPolicyID.cm")

# Call binary_to_human directly
{:ok, tlvs} = Bindocsis.parse(binary, enhanced: true)

# Build human config like HumanConfig does
human_tlvs = Enum.map(tlvs, fn tlv ->
  formatted_val = Map.get(tlv, :formatted_value) || "nil"
  
  base_tlv = %{
    "type" => tlv.type,
    "name" => tlv.name,
    "formatted_value" => formatted_val,
    "value_type" => Atom.to_string(tlv.value_type)
  }
  
  # Check if base_tlv has subtlvs
  if Map.has_key?(tlv, :subtlvs) and is_list(tlv.subtlvs) and length(tlv.subtlvs) > 0 do
    Map.put(base_tlv, "subtlvs", tlv.subtlvs)
  else
    base_tlv
  end
end)

human_config = %{
  "docsis_version" => "3.1",
  "tlvs" => human_tlvs
}

# Try to encode
case JSON.encode(human_config) do
  {:ok, _} ->
    IO.puts("✅ JSON encoding successful")
  {:error, error} ->
    IO.puts("❌ JSON encoding failed: #{inspect(error)}")
    
    # Look for non-UTF8 strings
    defmodule Check do
      def check_map(map, path \\ []) when is_map(map) do
        Enum.each(map, fn {k, v} ->
          check_value(v, path ++ [k])
        end)
      end
      
      def check_value(v, path) when is_binary(v) do
        case :unicode.characters_to_binary(v, :utf8, :utf8) do
          {:error, _, _} ->
            IO.puts("Non-UTF8 at #{Enum.join(path, ".")}: #{inspect(v)}")
          _ ->
            :ok
        end
      end
      
      def check_value(v, path) when is_list(v) do
        Enum.with_index(v, fn item, i ->
          check_value(item, path ++ ["[#{i}]"])
        end)
      end
      
      def check_value(v, path) when is_map(v) do
        check_map(v, path)
      end
      
      def check_value(_, _), do: :ok
    end
    
    Check.check_map(human_config)
end