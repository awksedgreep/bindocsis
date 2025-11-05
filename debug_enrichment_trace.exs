#!/usr/bin/env elixir

# Debug trace of Sub-TLV 3 enrichment

Code.append_path("_build/test/lib/bindocsis/ebin")

defmodule DebugEnrichment do
  def run do
    IO.puts("\n" <> IO.ANSI.cyan() <> "Tracing Sub-TLV 3 Enrichment" <> IO.ANSI.reset())
    IO.puts(String.duplicate("=", 70))

    # Create Sub-TLV 3 manually
    subtlv3 = %{
      type: 3,
      length: 4,
      value: <<0, 3, 13, 64>>  # 200,000
    }

    IO.puts("\nInput Sub-TLV:")
    IO.inspect(subtlv3, label: "subtlv3")

    # Get specs for TLV 4 (Class of Service)
    {:ok, cos_specs} = Bindocsis.SubTlvSpecs.get_subtlv_specs(4)

    IO.puts("\nClass of Service Sub-TLV specs:")
    IO.inspect(Map.get(cos_specs, 3), label: "Sub-TLV 3 spec")

    # Get the spec for Sub-TLV 3
    subtlv3_spec = Map.get(cos_specs, 3)

    IO.puts("\nSub-TLV 3 metadata from spec:")
    IO.puts("  name: #{subtlv3_spec.name}")
    IO.puts("  value_type: #{inspect(subtlv3_spec.value_type)}")
    IO.puts("  max_length: #{subtlv3_spec.max_length}")

    # Format the value using the correct value_type
    {:ok, formatted} = Bindocsis.ValueFormatter.format_value(
      subtlv3_spec.value_type,
      subtlv3.value,
      []
    )

    IO.puts("\nFormatted value (as #{subtlv3_spec.value_type}):")
    IO.puts("  #{inspect(formatted)}")

    # Now test if compound parsing would be attempted
    IO.puts("\nWould compound parsing be attempted?")
    IO.puts("  value_type from spec: #{inspect(subtlv3_spec.value_type)}")
    IO.puts("  value size: #{byte_size(subtlv3.value)} bytes")
    IO.puts("  has uint32 in atomic list?: #{subtlv3_spec.value_type in [:frequency, :boolean, :ipv4, :ipv6, :mac_address, :duration, :percentage, :power_quarter_db, :string, :uint8, :uint16, :uint32, :uint64, :int8, :int16, :int32, :binary, :asn1_der, :oid]}")

    has_atomic_type = subtlv3_spec.value_type in [:frequency, :boolean, :ipv4, :ipv6, :mac_address, :duration, :percentage, :power_quarter_db, :string, :uint8, :uint16, :uint32, :uint64, :int8, :int16, :int32, :binary, :asn1_der, :oid]
    long_enough = byte_size(subtlv3.value) >= 3
    would_attempt = long_enough && !has_atomic_type

    IO.puts("  Result: #{would_attempt}")

    # Now do full enrichment through the actual library
    IO.puts("\n" <> IO.ANSI.yellow() <> "Testing full enrichment flow:" <> IO.ANSI.reset())

    # Create full TLV 4 with Sub-TLV 3
    subtlvs = [
      %{type: 1, length: 1, value: <<1>>},
      %{type: 2, length: 4, value: <<0, 15, 66, 64>>},
      %{type: 3, length: 4, value: <<0, 3, 13, 64>>}
    ]

    {:ok, cos_value} = Bindocsis.Generators.BinaryGenerator.generate(subtlvs, terminate: false)

    tlv4 = %{
      type: 4,
      length: byte_size(cos_value),
      value: cos_value
    }

    IO.puts("\nTLV 4 before enrichment:")
    IO.inspect(tlv4, label: "TLV 4")

    # Enrich it
    enriched = Bindocsis.TlvEnricher.enrich_tlv(tlv4, enrich: true, format_values: true)

    IO.puts("\nTLV 4 after enrichment:")
    IO.inspect(enriched, limit: :infinity, pretty: true)

    if Map.has_key?(enriched, :subtlvs) do
      IO.puts("\nSub-TLVs:")
      Enum.each(enriched.subtlvs, fn subtlv ->
        IO.puts("\n  Sub-TLV #{subtlv.type}:")
        IO.puts("    name: #{Map.get(subtlv, :name, "N/A")}")
        IO.puts("    value_type: #{inspect(Map.get(subtlv, :value_type, "N/A"))}")
        IO.puts("    formatted_value: #{inspect(Map.get(subtlv, :formatted_value, "N/A"))}")
        IO.puts("    value (bytes): #{inspect(subtlv.value)}")
      end)
    end
  end
end

DebugEnrichment.run()
