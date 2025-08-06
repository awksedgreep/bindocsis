#!/usr/bin/env elixir

# Test script to validate the new unenrichment functionality

IO.puts("=== Testing TLV Unenrichment (Enriched → Raw → Binary) ===\n")

# Load the first fixture to get some real TLV data
files = Path.wildcard("test/fixtures/**/*.cm")
test_file = Enum.at(files, 0)

IO.puts("Using test file: #{Path.basename(test_file)}")

{:ok, binary} = File.read(test_file)

# Parse and enrich the TLVs
case Bindocsis.parse(binary) do
  {:ok, enriched_tlvs} ->
    IO.puts("\n=== Original Enriched TLVs ===")

    # Show the first few enriched TLVs
    enriched_tlvs
    |> Enum.take(3)
    |> Enum.with_index()
    |> Enum.each(fn {tlv, index} ->
      IO.puts("TLV #{index + 1}: Type #{tlv.type} (#{tlv.name || "Unknown"})")

      if Map.has_key?(tlv, :subtlvs) and is_list(tlv.subtlvs) and length(tlv.subtlvs) > 0 do
        IO.puts("  → Compound TLV with #{length(tlv.subtlvs)} subtlvs")
        IO.puts("  → No formatted_value (as expected)")
      else
        IO.puts("  → Leaf TLV with formatted_value: #{inspect(tlv[:formatted_value])}")
      end

      IO.puts("  → Value size: #{byte_size(tlv.value)} bytes")
      IO.puts("")
    end)

    # Now test unenrichment
    IO.puts("=== Testing Unenrichment ===")

    unenriched_tlvs = Bindocsis.TlvEnricher.unenrich_tlvs(enriched_tlvs)

    IO.puts("✅ Unenrichment completed!")
    IO.puts("Original: #{length(enriched_tlvs)} TLVs")
    IO.puts("Unenriched: #{length(unenriched_tlvs)} TLVs")

    # Show the first few unenriched TLVs
    IO.puts("\n=== Unenriched TLVs (Raw Format) ===")

    unenriched_tlvs
    |> Enum.take(3)
    |> Enum.with_index()
    |> Enum.each(fn {tlv, index} ->
      IO.puts(
        "TLV #{index + 1}: Type #{tlv.type}, Length #{tlv.length}, Value size #{byte_size(tlv.value)}"
      )

      # Show value preview
      value_preview =
        if byte_size(tlv.value) > 8 do
          first_8 = binary_part(tlv.value, 0, 8)

          hex_preview =
            first_8
            |> Base.encode16()
            |> String.graphemes()
            |> Enum.chunk_every(2)
            |> Enum.map(&Enum.join/1)
            |> Enum.join(" ")

          "#{hex_preview}..."
        else
          tlv.value
          |> Base.encode16()
          |> String.graphemes()
          |> Enum.chunk_every(2)
          |> Enum.map(&Enum.join/1)
          |> Enum.join(" ")
        end

      IO.puts("  → Value: #{value_preview}")
      IO.puts("")
    end)

    # Test binary generation with unenriched TLVs
    IO.puts("=== Testing Binary Generation ===")

    case Bindocsis.Generators.BinaryGenerator.generate(unenriched_tlvs) do
      {:ok, generated_binary} ->
        IO.puts("✅ Binary generation successful!")
        IO.puts("Original binary size: #{byte_size(binary)} bytes")
        IO.puts("Generated binary size: #{byte_size(generated_binary)} bytes")

        # Compare first 32 bytes
        if byte_size(binary) > 0 and byte_size(generated_binary) > 0 do
          original_preview =
            binary
            |> binary_part(0, min(32, byte_size(binary)))
            |> Base.encode16()
            |> String.graphemes()
            |> Enum.chunk_every(2)
            |> Enum.map(&Enum.join/1)
            |> Enum.join(" ")

          generated_preview =
            generated_binary
            |> binary_part(0, min(32, byte_size(generated_binary)))
            |> Base.encode16()
            |> String.graphemes()
            |> Enum.chunk_every(2)
            |> Enum.map(&Enum.join/1)
            |> Enum.join(" ")

          IO.puts("\nFirst 32 bytes comparison:")
          IO.puts("Original:  #{original_preview}")
          IO.puts("Generated: #{generated_preview}")

          if original_preview == generated_preview do
            IO.puts("🎉 Perfect match for first 32 bytes!")
          else
            IO.puts(
              "⚠️  Difference in first 32 bytes - this might be due to termination or padding differences"
            )
          end
        end

      {:error, reason} ->
        IO.puts("❌ Binary generation failed: #{reason}")
    end

    # Test the round-trip: Original → Enriched → Unenriched → Binary → Parsed → Enriched
    IO.puts("\n=== Testing Complete Round Trip ===")

    case Bindocsis.Generators.BinaryGenerator.generate(unenriched_tlvs) do
      {:ok, round_trip_binary} ->
        case Bindocsis.parse(round_trip_binary) do
          {:ok, round_trip_enriched_tlvs} ->
            IO.puts("✅ Complete round-trip successful!")
            IO.puts("Original enriched TLVs: #{length(enriched_tlvs)}")
            IO.puts("Round-trip enriched TLVs: #{length(round_trip_enriched_tlvs)}")

            # Compare some basic properties
            original_types = enriched_tlvs |> Enum.map(& &1.type) |> Enum.sort()
            round_trip_types = round_trip_enriched_tlvs |> Enum.map(& &1.type) |> Enum.sort()

            if original_types == round_trip_types do
              IO.puts("🎉 TLV types match perfectly!")
            else
              IO.puts("⚠️  TLV types differ:")
              IO.puts("  Original: #{inspect(original_types)}")
              IO.puts("  Round-trip: #{inspect(round_trip_types)}")
            end

          {:error, reason} ->
            IO.puts("❌ Round-trip parsing failed: #{reason}")
        end

      {:error, reason} ->
        IO.puts("❌ Round-trip binary generation failed: #{reason}")
    end

  {:error, reason} ->
    IO.puts("❌ Failed to parse test file: #{reason}")
end

IO.puts("\n=== Test Complete ===")
