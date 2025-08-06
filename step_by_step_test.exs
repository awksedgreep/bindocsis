#!/usr/bin/env elixir

Mix.install([{:jason, "~> 1.4"}])
Code.prepend_path("_build/dev/lib/bindocsis/ebin")

IO.puts("=== STEP 1: Binary to JSON ===")

# Test binary with the problematic TLV 18
original_binary = <<3, 1, 1, 18, 1, 0>>
IO.puts("Original binary: #{inspect(original_binary, base: :hex)}")

# Convert to JSON
case Bindocsis.convert(original_binary, from: :binary, to: :json) do
  {:ok, json_string} ->
    IO.puts("✅ Binary to JSON conversion succeeded")
    IO.puts("JSON string:")
    IO.puts(json_string)

    # Parse JSON to see structure
    case Jason.decode(json_string) do
      {:ok, parsed_json} ->
        IO.puts("\n✅ JSON parsing succeeded")
        IO.puts("Parsed JSON structure:")
        IO.inspect(parsed_json, pretty: true, limit: :infinity)

        # Find TLV 18 specifically
        tlv_18 = Enum.find(parsed_json["tlvs"], fn tlv -> tlv["type"] == 18 end)

        if tlv_18 do
          IO.puts("\n=== TLV 18 Details ===")
          IO.inspect(tlv_18, pretty: true, limit: :infinity)
          IO.puts("Has subtlvs?: #{Map.has_key?(tlv_18, "subtlvs")}")
          IO.puts("Has formatted_value?: #{Map.has_key?(tlv_18, "formatted_value")}")
          IO.puts("Has value?: #{Map.has_key?(tlv_18, "value")}")
        else
          IO.puts("❌ TLV 18 not found in parsed JSON!")
        end

      {:error, reason} ->
        IO.puts("❌ JSON parsing failed: #{reason}")
    end

  {:error, reason} ->
    IO.puts("❌ Binary to JSON conversion failed: #{reason}")
end
