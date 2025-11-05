#!/usr/bin/env elixir

# Direct raw binary parsing - no enrichment

Mix.install([{:bindocsis, path: "."}])

# Read raw binary
{:ok, binary} = File.read("25ccatv-base-v2.cm")

# Parse just the TLV structure - use private API for raw access
<<3, 1, 1,                           # TLV 3 (Network Access)
  24, 16, _ds1::binary-size(16),     # TLV 24 (Downstream Service Flow)
  25, 16, _us1::binary-size(16),     # TLV 25 (Upstream Service Flow)
  11, 21, snmp1::binary-size(21),   # TLV 11 (SNMP MIB Object) - FIRST ONE
  rest::binary>> = binary

IO.puts("First SNMP MIB Object (TLV 11):")
IO.puts("  Length: 21 bytes")

# Manually parse the sub-TLVs within this TLV 11
<<subtlv_type::8, subtlv_len::8, subtlv_rest::binary>> = snmp1

IO.puts("  First sub-TLV:")
IO.puts("    Type: #{subtlv_type}")
IO.puts("    Length: #{subtlv_len}")

# Extract the value
<<subtlv_value::binary-size(subtlv_len), remaining::binary>> = subtlv_rest

# Show the bytes
hex_bytes = subtlv_value
           |> :binary.bin_to_list()
           |> Enum.map(&Integer.to_string(&1, 16))
           |> Enum.map(&String.pad_leading(&1, 2, "0"))
           |> Enum.join(" ")

IO.puts("    Value (#{byte_size(subtlv_value)} bytes): #{hex_bytes}\n")

# If this is sub-TLV 48, try parsing it as TLVs
if subtlv_type == 48 do
  IO.puts("This is sub-TLV 48 (Object Value) - ASN.1 DER encoded data")
  IO.puts("Attempting to parse as TLVs...")

  # Try to parse as TLV
  <<fake_type::8, fake_len::8, fake_rest::binary>> = subtlv_value
  IO.puts("  Byte 0 (would be type): #{fake_type}")
  IO.puts("  Byte 1 (would be length): #{fake_len}")
  IO.puts("  These happen to form valid TLV structure, but they're actually ASN.1 DER data!")
end
