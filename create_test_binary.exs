#!/usr/bin/env elixir

# Create a binary that when parsed should produce TLVs 0, 9, 24
# Based on the evidence, the problem is the binary parser creating spurious TLV 0

# Let's create a minimal service flow binary that might trigger the issue
service_flow_binary = <<
  # TLV 24 (Downstream Service Flow) with sub-TLVs
  24, 7,                    # Type 24, Length 7
  1, 2, 0, 1, 6, 1, 7       # Sub-TLV data that might be parsed incorrectly
>>

IO.puts("Created service flow binary:")
hex_dump = service_flow_binary |> :binary.bin_to_list() |> Enum.map(&Integer.to_string(&1, 16) |> String.pad_leading(2, "0")) |> Enum.join(" ")
IO.puts("Binary content: #{hex_dump}")

# Save this binary for testing
File.write!("test/fixtures/bad_service_flow.bin", service_flow_binary)
IO.puts("Saved to test/fixtures/bad_service_flow.bin")

# Now let's test parsing this with the current parser
Mix.install([{:bindocsis, path: "."}])

case Bindocsis.parse(service_flow_binary, format: :binary) do
  {:ok, tlvs} ->
    IO.puts("Parsed TLVs:")
    for tlv <- tlvs do
      IO.puts("  TLV #{tlv.type}: length=#{tlv.length}, value=#{inspect(tlv.value)}")
    end
    
    tlv_types = tlvs |> Enum.map(&(&1.type)) |> Enum.sort()
    IO.puts("TLV types found: #{inspect(tlv_types)}")
    
    if Enum.sort([0, 9, 24]) == Enum.sort(tlv_types) do
      IO.puts("🚨 This binary produces the problematic TLV 0, 9, 24 pattern!")
    else
      IO.puts("This binary doesn't reproduce the issue. Need to find the actual problematic fixture.")
    end
    
  {:error, reason} ->
    IO.puts("Parse error: #{reason}")
end
