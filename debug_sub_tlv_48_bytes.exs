#!/usr/bin/env elixir

# Debug script to examine the raw bytes of sub-TLV 48 in SNMP MIB Objects

Mix.install([{:bindocsis, path: "."}])

alias Bindocsis

# Parse the binary file
{:ok, config} = Bindocsis.parse_file("25ccatv-base-v2.cm")

# config is a %Bindocsis.Config{} struct
# Find SNMP MIB Object TLVs (type 11)
snmp_tlvs = Enum.filter(config.tlvs, fn tlv -> tlv[:type] == 11 end)

IO.puts("Found #{length(snmp_tlvs)} SNMP MIB Object TLVs\n")

# Look at the first one
if snmp_tlv = List.first(snmp_tlvs) do
  IO.puts("First SNMP MIB Object:")
  IO.puts("  Type: #{snmp_tlv[:type]}")
  IO.puts("  Length: #{snmp_tlv[:length]}")
  IO.puts("  Value size: #{byte_size(snmp_tlv[:value])} bytes")

  # Parse the value to get sub-TLVs
  case Bindocsis.parse_tlv_binary(snmp_tlv[:value]) do
    {:ok, subtlvs} ->
      IO.puts("\n  Sub-TLVs found: #{length(subtlvs)}")

      # Find sub-TLV 48
      case Enum.find(subtlvs, fn sub -> sub[:type] == 48 end) do
        nil ->
          IO.puts("\n  No sub-TLV 48 found!")

        subtlv_48 ->
          IO.puts("\n  Sub-TLV 48 (Object Value):")
          IO.puts("    Type: #{subtlv_48[:type]}")
          IO.puts("    Length: #{subtlv_48[:length]}")
          IO.puts("    Value size: #{byte_size(subtlv_48[:value])} bytes")

          # Show raw bytes
          hex_bytes = subtlv_48[:value]
                     |> :binary.bin_to_list()
                     |> Enum.map(&Integer.to_string(&1, 16))
                     |> Enum.map(&String.pad_leading(&1, 2, "0"))
                     |> Enum.join(" ")

          IO.puts("    Raw bytes: #{hex_bytes}")

          # Try parsing as TLVs (this is what the enricher does)
          IO.puts("\n    Attempting to parse as TLVs...")
          case Bindocsis.parse_tlv_binary(subtlv_48[:value]) do
            {:ok, nested_tlvs} ->
              IO.puts("    Found #{length(nested_tlvs)} apparent TLVs:")
              Enum.each(nested_tlvs, fn tlv ->
                IO.puts("      - Type #{tlv[:type]}, Length #{tlv[:length]}")
              end)

            {:error, reason} ->
              IO.puts("    Failed to parse: #{reason}")
          end
      end

    {:error, reason} ->
      IO.puts("  Failed to parse sub-TLVs: #{reason}")
  end
end
