#!/usr/bin/env elixir

Mix.install([{:jason, "~> 1.4"}])
Code.prepend_path("_build/dev/lib/bindocsis/ebin")

defmodule StepByStepTest do
  def run_test() do
    IO.puts("=== STEP BY STEP DEBUGGING ===")

    # Original problematic binary
    original = <<3, 1, 1, 18, 1, 0>>
    IO.puts("1. Original binary: #{inspect(original, base: :hex)}")

    # Step 1: Parse binary to TLV structures
    IO.puts("\n2. Parsing binary to TLV structures...")

    case Bindocsis.parse(original, format: :binary, enhanced: true) do
      {:ok, tlvs} ->
        IO.puts("✅ Binary parsing succeeded")
        tlv_18 = Enum.find(tlvs, fn tlv -> tlv.type == 18 end)

        if tlv_18 do
          IO.puts("TLV 18 structure:")
          IO.inspect(tlv_18, pretty: true)
        end

        # Step 2: Generate JSON from TLV structures
        IO.puts("\n3. Generating JSON from TLV structures...")

        case Bindocsis.generate(tlvs, format: :json) do
          {:ok, json} ->
            IO.puts("✅ JSON generation succeeded")
            IO.puts("JSON: #{json}")

            # Parse JSON to see structure
            case Jason.decode(json) do
              {:ok, json_data} ->
                tlv_18_json = Enum.find(json_data["tlvs"], fn tlv -> tlv["type"] == 18 end)

                if tlv_18_json do
                  IO.puts("\nTLV 18 in JSON:")
                  IO.inspect(tlv_18_json, pretty: true)
                  IO.puts("Has subtlvs?: #{Map.has_key?(tlv_18_json, "subtlvs")}")
                end

                # Step 3: Convert JSON back to binary
                IO.puts("\n4. Converting JSON back to binary...")

                case Bindocsis.convert(json, from: :json, to: :binary) do
                  {:ok, result} ->
                    IO.puts("✅ JSON to binary conversion succeeded")
                    IO.puts("Result: #{inspect(result, base: :hex)}")

                    expected = <<3, 1, 1, 18, 1, 0, 255>>
                    IO.puts("Expected: #{inspect(expected, base: :hex)}")
                    IO.puts("Match: #{result == expected}")

                    if result != expected do
                      IO.puts("❌ MISMATCH FOUND!")
                      IO.puts("Result length: #{byte_size(result)}")
                      IO.puts("Expected length: #{byte_size(expected)}")
                    else
                      IO.puts("🎉 SUCCESS! Round-trip working correctly!")
                    end

                  {:error, reason} ->
                    IO.puts("❌ JSON to binary conversion failed: #{reason}")
                end

              {:error, reason} ->
                IO.puts("❌ JSON parsing failed: #{reason}")
            end

          {:error, reason} ->
            IO.puts("❌ JSON generation failed: #{reason}")
        end

      {:error, reason} ->
        IO.puts("❌ Binary parsing failed: #{reason}")
    end
  end
end

try do
  StepByStepTest.run_test()
rescue
  e ->
    IO.puts("ERROR: #{Exception.message(e)}")
    IO.puts(Exception.format_stacktrace(__STACKTRACE__))
end
