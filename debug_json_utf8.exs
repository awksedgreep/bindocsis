#!/usr/bin/env elixir

binary = File.read!("test/fixtures/TLV_22_43_1_CMLoadBalancingPolicyID.cm")
{:ok, tlvs} = Bindocsis.parse(binary, enhanced: true)

# Find TLV 22 and look at its subtlvs
tlv22 = Enum.find(tlvs, fn t -> t.type == 22 end)

if tlv22 && tlv22.subtlvs do
  IO.puts("TLV 22 has #{length(tlv22.subtlvs)} subtlvs")
  
  Enum.each(tlv22.subtlvs, fn subtlv ->
    if subtlv.type == 43 do
      IO.puts("\nTLV 43 subtlvs:")
      if subtlv.subtlvs do
        Enum.each(subtlv.subtlvs, fn sst ->
          IO.puts("  Type #{sst.type}: value_type=#{sst.value_type}")
          IO.puts("    formatted_value: #{inspect(sst.formatted_value)}")
          
          # Check if it's a valid UTF-8 string
          if is_binary(sst.formatted_value) do
            case :unicode.characters_to_binary(sst.formatted_value, :utf8, :utf8) do
              {:error, _, _} ->
                IO.puts("    ❌ NOT valid UTF-8!")
                # Convert to hex string
                hex = sst.formatted_value
                      |> :binary.bin_to_list()
                      |> Enum.map(&Integer.to_string(&1, 16))
                      |> Enum.map(&String.pad_leading(&1, 2, "0"))
                      |> Enum.join(" ")
                IO.puts("    As hex: #{hex}")
              _ ->
                IO.puts("    ✅ Valid UTF-8")
            end
          end
        end)
      end
    end
  end)
end