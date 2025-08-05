#!/usr/bin/env elixir

# Based on the investigation, create a binary with service flow sub-TLVs that might be parsed incorrectly
# TLV 24 (Downstream Service Flow) with sub-TLVs that include types 0 and 9

# This is based on analysis of service flow structures from compound_tlv_test.exs
# The issue seems to be that sub-TLV data is being parsed as standalone TLVs

# Create a service flow with sub-TLVs that could be misinterpreted
# Sub-TLV 0 should have type 0 (invalid for standalone) and sub-TLV 9 
service_flow_binary = <<
  # TLV 24 (Downstream Service Flow)  
  24, 10,                   # Type 24, Length 10
  # Sub-TLVs within the service flow that could be misinterpreted:
  0, 2, 6, 1,               # Sub-TLV 0 (2 bytes: 6, 1) - this might be parsed as standalone TLV 0
  9, 4, 1, 2, 3, 4          # Sub-TLV 9 (4 bytes: 1, 2, 3, 4) - this might be parsed as standalone TLV 9  
>>

IO.puts("Created problematic service flow binary:")
hex_dump = service_flow_binary |> :binary.bin_to_list() |> Enum.map(&Integer.to_string(&1, 16) |> String.pad_leading(2, "0")) |> Enum.join(" ")
IO.puts("Binary content: #{hex_dump}")

# Save this to the fixtures directory
File.write!("test/fixtures/bad_service_flow.bin", service_flow_binary)
IO.puts("Saved to test/fixtures/bad_service_flow.bin")

# Test with the current parser
Mix.install([{:bindocsis, path: "."}])

IO.puts("\nTesting with current parser:")
case Bindocsis.parse(service_flow_binary, format: :binary) do
  {:ok, tlvs} ->
    IO.puts("Parsed TLVs:")
    for tlv <- tlvs do
      IO.puts("  TLV #{tlv.type}: length=#{tlv.length}, value=#{inspect(tlv.value)}")
    end
    
    tlv_types = tlvs |> Enum.map(&(&1.type)) |> Enum.sort()
    IO.puts("\nTLV types found: #{inspect(tlv_types)}")
    
    if Enum.sort([0, 9, 24]) == Enum.sort(tlv_types) do
      IO.puts("🚨 SUCCESS! This binary reproduces the TLV 0, 9, 24 issue!")
      
      # Show the problematic TLV 0 
      tlv_0 = Enum.find(tlvs, &(&1.type == 0))
      if tlv_0 do
        IO.puts("Problematic TLV 0: length=#{tlv_0.length}, value=#{inspect(tlv_0.value)}")
        if tlv_0.length == 2 do
          IO.puts("✓ Confirmed: TLV 0 has invalid 2-byte length (should be 1)")
        end
      end
      
    else
      IO.puts("This binary doesn't reproduce the exact issue pattern.")
    end
    
  {:error, reason} ->
    IO.puts("Parse error: #{reason}")
end
