#!/usr/bin/env elixir

# Phase 3.1: Test actual Bindocsis value conversion
# This tests the real library functions to find bugs

Code.require_file("lib/bindocsis.ex")
Code.require_file("lib/bindocsis/value_parser.ex")
Code.require_file("lib/bindocsis/value_formatter.ex")
Code.require_file("lib/bindocsis/docsis_specs.ex")
Code.require_file("lib/bindocsis/sub_tlv_specs.ex")

defmodule ActualValueTest do
  def run do
    IO.puts("\n" <> IO.ANSI.cyan() <> "Testing Actual Bindocsis Value Conversion" <> IO.ANSI.reset())
    IO.puts(String.duplicate("=", 70))

    # Test uint32 (the problematic case from round-trip tests)
    test_uint32_conversion()

    # Test through full TLV structure
    test_full_tlv_roundtrip()
  end

  defp test_uint32_conversion do
    IO.puts("\n" <> IO.ANSI.yellow() <> "Test 1: Direct uint32 value conversion" <> IO.ANSI.reset())

    original_value = <<0, 15, 66, 64>>  # 1,000,000
    IO.puts("Original binary: #{inspect(original_value)}")
    IO.puts("Original as integer: #{:binary.decode_unsigned(original_value)}")

    # Test ValueFormatter
    case Bindocsis.ValueFormatter.format_value(:uint32, original_value, []) do
      {:ok, formatted} ->
        IO.puts("✓ Formatted: #{inspect(formatted)}")

        # Test ValueParser
        case Bindocsis.ValueParser.parse_value(:uint32, formatted, []) do
          {:ok, parsed} ->
            IO.puts("✓ Parsed back: #{inspect(parsed)}")

            if parsed == original_value do
              IO.puts(IO.ANSI.green() <> "✅ Round-trip SUCCESS" <> IO.ANSI.reset())
            else
              IO.puts(IO.ANSI.red() <> "❌ Round-trip FAILED" <> IO.ANSI.reset())
              IO.puts("  Expected: #{inspect(original_value)}")
              IO.puts("  Got:      #{inspect(parsed)}")
            end

          {:error, reason} ->
            IO.puts(IO.ANSI.red() <> "❌ Parse failed: #{reason}" <> IO.ANSI.reset())
        end

      {:error, reason} ->
        IO.puts(IO.ANSI.red() <> "❌ Format failed: #{reason}" <> IO.ANSI.reset())
    end
  end

  defp test_full_tlv_roundtrip do
    IO.puts("\n" <> IO.ANSI.yellow() <> "Test 2: Full TLV round-trip (Binary → JSON → Binary)" <> IO.ANSI.reset())

    # Create a simple TLV with uint32 value
    # TLV 4 Sub-TLV 1 (Max Rate Downstream) = 1,000,000
    tlv_binary = <<
      4, 11,  # TLV 4 (Class of Service), length 11
      1, 9,   # Sub-TLV 1 (Class ID), length 9
      1, 4, <<0, 15, 66, 64>>::binary,  # Sub-sub-TLV 1 (Max Rate Downstream), length 4, value 1000000
      2, 1, 5  # Sub-sub-TLV 2 (Priority), length 1, value 5
    >>

    IO.puts("Original binary (#{byte_size(tlv_binary)} bytes):")
    IO.puts("  " <> inspect(tlv_binary, limit: :infinity))

    # Step 1: Parse binary
    IO.puts("\nStep 1: Parse binary...")
    case Bindocsis.parse(tlv_binary, format: :binary, enrich: true) do
      {:ok, tlvs} ->
        IO.puts("✓ Parsed #{length(tlvs)} TLV(s)")
        IO.inspect(tlvs, limit: :infinity, pretty: true)

        # Step 2: Convert to JSON
        IO.puts("\nStep 2: Convert to JSON...")
        case Bindocsis.HumanConfig.to_json(tlvs, []) do
          {:ok, json_string} ->
            IO.puts("✓ Generated JSON:")
            IO.puts(json_string)

            # Step 3: Parse JSON back
            IO.puts("\nStep 3: Parse JSON back to TLVs...")
            json_data = Jason.decode!(json_string)

            case Bindocsis.HumanConfig.from_json(json_data, []) do
              {:ok, parsed_tlvs} ->
                IO.puts("✓ Parsed back #{length(parsed_tlvs)} TLV(s)")

                # Step 4: Generate binary
                IO.puts("\nStep 4: Generate binary...")
                case Bindocsis.Generators.BinaryGenerator.generate(parsed_tlvs, []) do
                  {:ok, final_binary} ->
                    IO.puts("✓ Generated binary (#{byte_size(final_binary)} bytes):")
                    IO.puts("  " <> inspect(final_binary, limit: :infinity))

                    # Compare
                    IO.puts("\nComparison:")
                    if final_binary == tlv_binary do
                      IO.puts(IO.ANSI.green() <> "✅ PERFECT MATCH!" <> IO.ANSI.reset())
                    else
                      IO.puts(IO.ANSI.red() <> "❌ MISMATCH" <> IO.ANSI.reset())
                      show_diff(tlv_binary, final_binary)
                    end

                  {:error, reason} ->
                    IO.puts(IO.ANSI.red() <> "❌ Binary generation failed: #{inspect(reason)}" <> IO.ANSI.reset())
                end

              {:error, reason} ->
                IO.puts(IO.ANSI.red() <> "❌ JSON parse failed: #{inspect(reason)}" <> IO.ANSI.reset())
            end

          {:error, reason} ->
            IO.puts(IO.ANSI.red() <> "❌ JSON generation failed: #{inspect(reason)}" <> IO.ANSI.reset())
        end

      {:error, reason} ->
        IO.puts(IO.ANSI.red() <> "❌ Binary parse failed: #{inspect(reason)}" <> IO.ANSI.reset())
    end
  end

  defp show_diff(expected, got) do
    exp_bytes = :binary.bin_to_list(expected)
    got_bytes = :binary.bin_to_list(got)

    IO.puts("\nByte-by-byte comparison:")
    IO.puts("  Original: #{inspect(exp_bytes)}")
    IO.puts("  Final:    #{inspect(got_bytes)}")

    IO.puts("\nDifferences:")
    max_len = max(length(exp_bytes), length(got_bytes))

    Enum.zip(
      exp_bytes ++ List.duplicate(nil, max_len - length(exp_bytes)),
      got_bytes ++ List.duplicate(nil, max_len - length(got_bytes))
    )
    |> Enum.with_index()
    |> Enum.each(fn {{e, g}, idx} ->
      if e != g do
        IO.puts("  Byte #{idx}: #{inspect(e)} → #{inspect(g)}")
      end
    end)
  end
end

# Check if required modules are available
try do
  ActualValueTest.run()
rescue
  e ->
    IO.puts(IO.ANSI.red() <> "\n❌ Error: #{inspect(e)}" <> IO.ANSI.reset())
    IO.puts("\nThis test requires compiled modules. Run: mix test")
end
