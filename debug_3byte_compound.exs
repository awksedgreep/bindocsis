#!/usr/bin/env elixir

# Test parsing a 3-byte value as compound TLV
test_value = <<255, 255, 255>>  # 3 bytes

IO.puts("Testing 3-byte compound TLV parsing...")
case Bindocsis.TlvParser.parse_tlv_binary(test_value) do
  {:ok, tlvs} ->
    IO.puts("✅ Parse succeeded, found #{length(tlvs)} TLVs")
    Enum.each(tlvs, fn tlv ->
      IO.puts("  TLV type=#{tlv.type}, length=#{tlv.length}, value_size=#{byte_size(tlv.value)}")
    end)
  {:error, reason} ->
    IO.puts("❌ Parse failed: #{reason}")
end

# Test with a 2-byte value
test_value2 = <<0, 1>>  # 2 bytes
IO.puts("\nTesting 2-byte compound TLV parsing...")
case Bindocsis.TlvParser.parse_tlv_binary(test_value2) do
  {:ok, tlvs} ->
    IO.puts("✅ Parse succeeded, found #{length(tlvs)} TLVs")
    Enum.each(tlvs, fn tlv ->
      IO.puts("  TLV type=#{tlv.type}, length=#{tlv.length}, value_size=#{byte_size(tlv.value)}")
    end)
  {:error, reason} ->
    IO.puts("❌ Parse failed: #{reason}")
end

# Test with actual TLV 43.8 data
IO.puts("\nChecking actual TLV 43.8 data...")
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
      IO.puts("  value_type: #{tlv8.value_type}")
      IO.puts("  formatted_value: #{inspect(tlv8.formatted_value)}")
      IO.puts("  subtlvs: #{inspect(tlv8[:subtlvs])}")
    end
  end
end