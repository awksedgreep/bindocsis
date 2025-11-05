#!/usr/bin/env elixir

# Simple test - directly read binary file and parse TLV 11

Mix.install([{:bindocsis, path: "."}])

# Read raw binary
{:ok, binary} = File.read("25ccatv-base-v2.cm")

# Parse into raw TLVs (not enriched) - disable enrichment
{:ok, config} = Bindocsis.parse(binary, enrich: false)
raw_tlvs = config.tlvs

# Find first TLV 11 (SNMP MIB Object)
snmp_tlv = Enum.find(raw_tlvs, fn tlv -> tlv.type == 11 end)

if snmp_tlv do
  IO.puts("Found SNMP MIB Object TLV 11:")
  IO.puts("  Value size: #{byte_size(snmp_tlv.value)} bytes\n")

  # Parse its value to get sub-TLVs
  {:ok, subtlvs} = Bindocsis.parse_tlv_binary(snmp_tlv.value)

  # Find sub-TLV 48
  subtlv_48 = Enum.find(subtlvs, fn sub -> sub.type == 48 end)

  if subtlv_48 do
    IO.puts("Sub-TLV 48 (Object Value):")
    IO.puts("  Type: #{subtlv_48.type}")
    IO.puts("  Length: #{subtlv_48.length}")
    IO.puts("  Value size: #{byte_size(subtlv_48.value)} bytes")

    # Show raw bytes
    hex_bytes = subtlv_48.value
               |> :binary.bin_to_list()
               |> Enum.map(&Integer.to_string(&1, 16))
               |> Enum.map(&String.pad_leading(&1, 2, "0"))
               |> Enum.join(" ")

    IO.puts("  Raw bytes: #{hex_bytes}\n")

    # Try parsing as TLVs (this is what the enricher accidentally does)
    IO.puts("Attempting to parse ASN.1 DER bytes as TLVs...")
    case Bindocsis.parse_tlv_binary(subtlv_48.value) do
      {:ok, fake_tlvs} ->
        IO.puts("Parser found #{length(fake_tlvs)} apparent 'TLVs':")
        Enum.each(fake_tlvs, fn tlv ->
          IO.puts("  - Type #{tlv.type}, Length #{tlv.length}")
        end)
        IO.puts("\nThese are NOT real TLVs - they're just ASN.1 DER bytes that happen to look like TLV structures!")

      {:error, reason} ->
        IO.puts("Failed to parse (good - means it doesn't look like TLVs): #{reason}")
    end
  else
    IO.puts("No sub-TLV 48 found!")
  end
else
  IO.puts("No TLV 11 found!")
end
