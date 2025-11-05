#!/usr/bin/env elixir

# Isolate the exact round-trip bug: 15 bytes → 14 bytes

Mix.install([{:jason, "~> 1.4"}])

Code.append_path("_build/test/lib/bindocsis/ebin")
Code.append_path("_build/test/lib/yaml_elixir/ebin")
Code.append_path("_build/test/lib/yamerl/ebin")

defmodule IsolateBug do
  def run do
    IO.puts("\n" <> IO.ANSI.cyan() <> "Isolating the 15 → 14 byte bug" <> IO.ANSI.reset())
    IO.puts(String.duplicate("=", 70))

    # Create the exact TLV structure from the failing test
    cos_subtlvs = [
      %{type: 1, length: 1, value: <<1>>},
      %{type: 2, length: 4, value: <<1_000_000::32>>},
      %{type: 3, length: 4, value: <<200_000::32>>}
    ]

    IO.puts("\nOriginal Sub-TLVs:")
    Enum.each(cos_subtlvs, fn subtlv ->
      IO.puts("  Type #{subtlv.type}, Length #{subtlv.length}, Value: #{inspect(subtlv.value)}")
    end)

    # Generate binary for sub-TLVs
    {:ok, cos_value} = Bindocsis.Generators.BinaryGenerator.generate(cos_subtlvs, terminate: false)

    IO.puts("\nGenerated Sub-TLV binary (#{byte_size(cos_value)} bytes):")
    IO.puts("  " <> inspect(cos_value, limit: :infinity))
    IO.puts("  Hex: " <> Base.encode16(cos_value))

    # Create TLV 4 (Class of Service) with these sub-TLVs
    original_tlvs = [
      %{type: 3, length: 1, value: <<1>>},
      %{type: 4, length: byte_size(cos_value), value: cos_value},
      %{type: 21, length: 1, value: <<5>>}
    ]

    IO.puts("\nOriginal TLVs:")
    Enum.each(original_tlvs, fn tlv ->
      IO.puts("  Type #{tlv.type}, Length #{tlv.length}")
    end)

    # Step 1: Generate binary
    {:ok, binary_data} = Bindocsis.Generators.BinaryGenerator.generate(original_tlvs)
    IO.puts("\nStep 1: Generated binary (#{byte_size(binary_data)} bytes)")
    IO.puts("  " <> inspect(binary_data, limit: :infinity))

    # Step 2: Parse binary (with enrichment)
    {:ok, parsed_tlvs} = Bindocsis.parse(binary_data, format: :binary, enrich: true)
    IO.puts("\nStep 2: Parsed with enrichment (#{length(parsed_tlvs)} TLVs)")

    # Look at TLV 4 specifically
    tlv4 = Enum.find(parsed_tlvs, & &1.type == 4)
    IO.puts("\nTLV 4 after parsing:")
    IO.puts("  Type: #{tlv4.type}")
    IO.puts("  Length: #{tlv4.length}")
    IO.puts("  Value (#{byte_size(tlv4.value)} bytes): #{inspect(tlv4.value, limit: :infinity)}")
    if Map.has_key?(tlv4, :subtlvs) do
      IO.puts("  Subtlvs: #{length(tlv4.subtlvs)} items")
      Enum.each(tlv4.subtlvs, fn subtlv ->
        formatted = Map.get(subtlv, :formatted_value, "N/A")
        IO.puts("    Sub-TLV #{subtlv.type}: #{inspect(formatted)}")
      end)
    end

    # Step 3: Generate JSON
    {:ok, json_content} = Bindocsis.Generators.JsonGenerator.generate(parsed_tlvs)
    IO.puts("\nStep 3: Generated JSON")
    IO.puts(json_content)

    # Step 4: Parse JSON back
    {:ok, json_parsed_tlvs} = Bindocsis.parse(json_content, format: :json)
    IO.puts("\nStep 4: Parsed from JSON (#{length(json_parsed_tlvs)} TLVs)")

    # Look at TLV 4 after JSON round-trip
    tlv4_json = Enum.find(json_parsed_tlvs, & &1.type == 4)
    IO.puts("\nTLV 4 after JSON round-trip:")
    IO.puts("  Type: #{tlv4_json.type}")
    IO.puts("  Length: #{tlv4_json.length}")
    IO.puts("  Value (#{byte_size(tlv4_json.value)} bytes): #{inspect(tlv4_json.value, limit: :infinity)}")

    # Step 5: Generate final binary
    {:ok, final_binary} = Bindocsis.Generators.BinaryGenerator.generate(json_parsed_tlvs)
    IO.puts("\nStep 5: Final binary (#{byte_size(final_binary)} bytes)")
    IO.puts("  " <> inspect(final_binary, limit: :infinity))

    # Step 6: Parse final binary
    {:ok, final_tlvs} = Bindocsis.parse(final_binary, format: :binary)
    IO.puts("\nStep 6: Final parsed TLVs (#{length(final_tlvs)} TLVs)")

    tlv4_final = Enum.find(final_tlvs, & &1.type == 4)
    IO.puts("\nTLV 4 final state:")
    IO.puts("  Type: #{tlv4_final.type}")
    IO.puts("  Length: #{tlv4_final.length}")
    IO.puts("  Value (#{byte_size(tlv4_final.value)} bytes): #{inspect(tlv4_final.value, limit: :infinity)}")

    # Compare
    IO.puts("\n" <> IO.ANSI.yellow() <> "Comparison:" <> IO.ANSI.reset())
    IO.puts("Original length: #{tlv4.length}")
    IO.puts("Final length: #{tlv4_final.length}")

    if tlv4.length == tlv4_final.length do
      IO.puts(IO.ANSI.green() <> "✅ Length preserved!" <> IO.ANSI.reset())
    else
      IO.puts(IO.ANSI.red() <> "❌ Length mismatch: #{tlv4.length} → #{tlv4_final.length}" <> IO.ANSI.reset())
      IO.puts("\nByte difference:")
      show_byte_diff(tlv4.value, tlv4_final.value)
    end
  end

  defp show_byte_diff(original, final) do
    orig_bytes = :binary.bin_to_list(original)
    final_bytes = :binary.bin_to_list(final)

    IO.puts("  Original (#{length(orig_bytes)} bytes): #{inspect(orig_bytes)}")
    IO.puts("  Final (#{length(final_bytes)} bytes):    #{inspect(final_bytes)}")

    IO.puts("\n  Hex comparison:")
    IO.puts("  Original: " <> Base.encode16(original))
    IO.puts("  Final:    " <> Base.encode16(final))
  end
end

IsolateBug.run()
