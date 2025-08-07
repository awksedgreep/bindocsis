#!/usr/bin/env elixir

# Check actual TLV 43.8 data
IO.puts("Checking actual TLV 43.8 data...")
binary = File.read!("test/fixtures/TLV_22_43_1_CMLoadBalancingPolicyID.cm")
{:ok, tlvs} = Bindocsis.parse(binary, enhanced: true)

tlv22 = Enum.find(tlvs, fn t -> t.type == 22 end)
if tlv22 && tlv22.subtlvs do
  tlv43 = Enum.find(tlv22.subtlvs, fn t -> t.type == 43 end)
  if tlv43 && tlv43.subtlvs do
    tlv8 = Enum.find(tlv43.subtlvs, fn t -> t.type == 8 end)
    if tlv8 do
      IO.puts("Found TLV 43.8:")
      IO.puts("  value: #{inspect(tlv8.value)}")
      IO.puts("  value_size: #{byte_size(tlv8.value)} bytes")
      IO.puts("  value_type: #{tlv8.value_type}")
      IO.puts("  formatted_value: #{inspect(tlv8.formatted_value)}")
      IO.puts("  subtlvs: #{inspect(tlv8[:subtlvs])}")
      
      # Show raw hex
      hex = tlv8.value
            |> :binary.bin_to_list()
            |> Enum.map(&Integer.to_string(&1, 16))
            |> Enum.map(&String.pad_leading(&1, 2, "0"))
            |> Enum.join(" ")
      IO.puts("  value as hex: #{hex}")
    end
  end
end