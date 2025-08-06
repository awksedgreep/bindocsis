#!/usr/bin/env elixir

# Debug a specific failing fixture to see the JSON structure

IO.puts("=== Debug JSON Generation for BaseConfig ===\n")

{:ok, binary} = File.read("test/fixtures/BaseConfig.cm")

case Bindocsis.parse(binary) do
  {:ok, tlvs} ->
    IO.puts("=== Parsed TLVs ===")

    Enum.each(Enum.take(tlvs, 3), fn tlv ->
      IO.puts("TLV #{tlv.type}: #{tlv.name || "Unknown"}")

      if Map.has_key?(tlv, :subtlvs) and is_list(tlv.subtlvs) and length(tlv.subtlvs) > 0 do
        IO.puts("  → Has subtlvs: #{length(tlv.subtlvs)}")
        IO.puts("  → subtlvs present: ✅")
      else
        IO.puts("  → subtlvs: ❌ #{inspect(Map.get(tlv, :subtlvs, "missing"))}")
      end

      if Map.has_key?(tlv, :formatted_value) do
        IO.puts("  → Has formatted_value: ✅ #{inspect(tlv.formatted_value)}")
      else
        IO.puts("  → formatted_value: ❌")
      end

      IO.puts("")
    end)

    # Test JSON generation with detect_subtlvs: false
    IO.puts("=== Testing JSON Generation (detect_subtlvs: false) ===")

    case Bindocsis.generate(tlvs, format: :json, detect_subtlvs: false) do
      {:ok, json} ->
        IO.puts("✅ JSON generation successful")

        # Parse and inspect the JSON structure for the first compound TLV
        case Jason.decode(json) do
          {:ok, parsed_json} ->
            json_tlvs = parsed_json["tlvs"] || []

            IO.puts("\n=== JSON TLV Structure ===")

            Enum.each(Enum.take(json_tlvs, 3), fn json_tlv ->
              type = json_tlv["type"]
              IO.puts("JSON TLV #{type}:")

              if Map.has_key?(json_tlv, "subtlvs") do
                IO.puts("  → Has subtlvs in JSON: ✅ #{length(json_tlv["subtlvs"] || [])}")
              else
                IO.puts("  → subtlvs in JSON: ❌")
              end

              if Map.has_key?(json_tlv, "formatted_value") do
                IO.puts("  → Has formatted_value in JSON: ✅")
              else
                IO.puts("  → formatted_value in JSON: ❌")
              end

              IO.puts("")
            end)

          {:error, reason} ->
            IO.puts("❌ JSON parsing failed: #{reason}")
        end

      {:error, reason} ->
        IO.puts("❌ JSON generation failed: #{reason}")
    end

  {:error, reason} ->
    IO.puts("❌ Failed to parse fixture: #{reason}")
end
