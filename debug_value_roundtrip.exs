#!/usr/bin/env elixir

# Phase 3.1: Comprehensive Value Round-Trip Diagnostic
# Tests each value type through the conversion pipeline to find corruption points

Mix.install([{:yaml_elixir, "~> 2.9"}])

defmodule ValueRoundTripDiagnostic do
  @moduledoc """
  Diagnoses value conversion failures in JSON/YAML round-trips.

  Tests each value type:
  1. Binary → Enriched (formatted_value)
  2. Enriched → JSON
  3. JSON → Binary
  4. Compare original vs final binary
  """

  def run do
    IO.puts("\n" <> IO.ANSI.cyan() <> "Value Round-Trip Diagnostic" <> IO.ANSI.reset())
    IO.puts(String.duplicate("=", 60))

    test_cases = [
      # uint8 tests
      {:uint8, <<0>>, "0", "uint8 zero"},
      {:uint8, <<1>>, "1", "uint8 one"},
      {:uint8, <<127>>, "127", "uint8 boundary 127"},
      {:uint8, <<128>>, "128", "uint8 boundary 128"},
      {:uint8, <<255>>, "255", "uint8 max"},

      # uint16 tests
      {:uint16, <<0, 0>>, "0", "uint16 zero"},
      {:uint16, <<0, 1>>, "1", "uint16 one"},
      {:uint16, <<1, 0>>, "256", "uint16 256"},
      {:uint16, <<255, 255>>, "65535", "uint16 max"},

      # uint32 tests
      {:uint32, <<0, 0, 0, 0>>, "0", "uint32 zero"},
      {:uint32, <<0, 0, 0, 1>>, "1", "uint32 one"},
      {:uint32, <<0, 0, 1, 0>>, "256", "uint32 256"},
      {:uint32, <<0, 15, 66, 64>>, "1000000", "uint32 1 million"},
      {:uint32, <<255, 255, 255, 255>>, "4294967295", "uint32 max"},

      # frequency tests (uint32 with Hz)
      {:frequency, <<35, 59, 241, 192>>, "591000000", "frequency 591 MHz"},
      {:frequency, <<35, 59, 241, 192>>, "591 MHz", "frequency with unit"},

      # ipv4 tests
      {:ipv4, <<192, 168, 1, 1>>, "192.168.1.1", "ipv4 private"},
      {:ipv4, <<10, 0, 0, 1>>, "10.0.0.1", "ipv4 10.x"},

      # string tests
      {:string, <<"test">>, "test", "simple string"},
      {:string, <<"DOCSIS 3.1">>, "DOCSIS 3.1", "string with space"},

      # hex_string tests
      {:hex_string, <<0x01, 0x02, 0x03>>, "01 02 03", "hex_string simple"},
      {:hex_string, <<0xFF, 0xFE, 0xFD>>, "FF FE FD", "hex_string high"},
    ]

    results = Enum.map(test_cases, &test_value_type/1)

    # Summary
    IO.puts("\n" <> IO.ANSI.cyan() <> "Summary" <> IO.ANSI.reset())
    IO.puts(String.duplicate("=", 60))

    passed = Enum.count(results, & &1 == :pass)
    failed = Enum.count(results, & &1 == :fail)
    total = length(results)

    IO.puts("Total: #{total}")
    IO.puts(IO.ANSI.green() <> "Passed: #{passed}" <> IO.ANSI.reset())
    IO.puts(IO.ANSI.red() <> "Failed: #{failed}" <> IO.ANSI.reset())

    if failed > 0 do
      IO.puts("\n" <> IO.ANSI.yellow() <> "⚠️  Value conversion has bugs that need fixing" <> IO.ANSI.reset())
    else
      IO.puts("\n" <> IO.ANSI.green() <> "✅ All value types pass round-trip!" <> IO.ANSI.reset())
    end
  end

  defp test_value_type({value_type, original_binary, expected_formatted, description}) do
    IO.puts("\n" <> IO.ANSI.yellow() <> "Testing: #{description}" <> IO.ANSI.reset())
    IO.puts("  Type: #{value_type}")
    IO.puts("  Original binary: #{inspect(original_binary, limit: :infinity)}")
    IO.puts("  Expected formatted: #{inspect(expected_formatted)}")

    # Step 1: Format (binary → formatted_value)
    formatted = format_value(value_type, original_binary)
    IO.puts("  → Formatted: #{inspect(formatted)}")

    format_match = formatted == expected_formatted
    if format_match do
      IO.puts("    " <> IO.ANSI.green() <> "✓ Format OK" <> IO.ANSI.reset())
    else
      IO.puts("    " <> IO.ANSI.red() <> "✗ Format MISMATCH" <> IO.ANSI.reset())
    end

    # Step 2: Parse (formatted_value → binary)
    parsed_binary = parse_value(value_type, formatted)
    IO.puts("  → Parsed binary: #{inspect(parsed_binary, limit: :infinity)}")

    parse_match = parsed_binary == original_binary
    if parse_match do
      IO.puts("    " <> IO.ANSI.green() <> "✓ Parse OK" <> IO.ANSI.reset())
    else
      IO.puts("    " <> IO.ANSI.red() <> "✗ Parse MISMATCH" <> IO.ANSI.reset())
      IO.puts("      Expected: #{inspect(original_binary, limit: :infinity)}")
      IO.puts("      Got:      #{inspect(parsed_binary, limit: :infinity)}")

      # Show byte-by-byte difference
      if is_binary(parsed_binary) do
        show_byte_diff(original_binary, parsed_binary)
      end
    end

    # Overall result
    if format_match and parse_match do
      IO.puts("  " <> IO.ANSI.green() <> "✅ PASS" <> IO.ANSI.reset())
      :pass
    else
      IO.puts("  " <> IO.ANSI.red() <> "❌ FAIL" <> IO.ANSI.reset())
      :fail
    end
  end

  defp format_value(:uint8, <<value::8>>), do: Integer.to_string(value)
  defp format_value(:uint16, <<value::16>>), do: Integer.to_string(value)
  defp format_value(:uint32, <<value::32>>), do: Integer.to_string(value)
  defp format_value(:frequency, <<freq::32>>), do: Integer.to_string(freq)
  defp format_value(:ipv4, <<a, b, c, d>>), do: "#{a}.#{b}.#{c}.#{d}"
  defp format_value(:string, value) when is_binary(value), do: value
  defp format_value(:hex_string, value) do
    value
    |> :binary.bin_to_list()
    |> Enum.map(&String.upcase(Integer.to_string(&1, 16)))
    |> Enum.map(&String.pad_leading(&1, 2, "0"))
    |> Enum.join(" ")
  end
  defp format_value(_, value), do: inspect(value)

  defp parse_value(:uint8, value) when is_binary(value) do
    case Integer.parse(value) do
      {int, ""} when int >= 0 and int <= 255 -> <<int::8>>
      _ -> {:error, "Invalid uint8: #{value}"}
    end
  end

  defp parse_value(:uint16, value) when is_binary(value) do
    case Integer.parse(value) do
      {int, ""} when int >= 0 and int <= 65535 -> <<int::16>>
      _ -> {:error, "Invalid uint16: #{value}"}
    end
  end

  defp parse_value(:uint32, value) when is_binary(value) do
    case Integer.parse(value) do
      {int, ""} when int >= 0 and int <= 4_294_967_295 -> <<int::32>>
      _ -> {:error, "Invalid uint32: #{value}"}
    end
  end

  defp parse_value(:frequency, value) when is_binary(value) do
    # Handle "591 MHz" or "591000000"
    cond do
      String.contains?(value, "MHz") ->
        [num | _] = String.split(value)
        case Integer.parse(num) do
          {mhz, ""} -> <<(mhz * 1_000_000)::32>>
          _ -> {:error, "Invalid frequency: #{value}"}
        end

      true ->
        case Integer.parse(value) do
          {freq, ""} -> <<freq::32>>
          _ -> {:error, "Invalid frequency: #{value}"}
        end
    end
  end

  defp parse_value(:ipv4, value) when is_binary(value) do
    case String.split(value, ".") do
      [a, b, c, d] ->
        with {a_int, ""} <- Integer.parse(a),
             {b_int, ""} <- Integer.parse(b),
             {c_int, ""} <- Integer.parse(c),
             {d_int, ""} <- Integer.parse(d) do
          <<a_int, b_int, c_int, d_int>>
        else
          _ -> {:error, "Invalid IP: #{value}"}
        end

      _ ->
        {:error, "Invalid IP format: #{value}"}
    end
  end

  defp parse_value(:string, value) when is_binary(value), do: value

  defp parse_value(:hex_string, value) when is_binary(value) do
    value
    |> String.split()
    |> Enum.map(fn hex ->
      case Integer.parse(hex, 16) do
        {byte, ""} -> byte
        _ -> nil
      end
    end)
    |> case do
      bytes when is_list(bytes) ->
        if Enum.all?(bytes, & &1 != nil) do
          :binary.list_to_bin(bytes)
        else
          {:error, "Invalid hex: #{value}"}
        end

      _ ->
        {:error, "Invalid hex: #{value}"}
    end
  end

  defp parse_value(_, value), do: {:error, "Unknown type for value: #{inspect(value)}"}

  defp show_byte_diff(expected, got) do
    exp_bytes = :binary.bin_to_list(expected)
    got_bytes = :binary.bin_to_list(got)

    IO.puts("      Byte-by-byte comparison:")
    IO.puts("        Expected: #{inspect(exp_bytes)}")
    IO.puts("        Got:      #{inspect(got_bytes)}")

    max_len = max(length(exp_bytes), length(got_bytes))
    exp_padded = exp_bytes ++ List.duplicate(nil, max_len - length(exp_bytes))
    got_padded = got_bytes ++ List.duplicate(nil, max_len - length(got_bytes))

    Enum.zip(exp_padded, got_padded)
    |> Enum.with_index()
    |> Enum.each(fn {{e, g}, idx} ->
      if e != g do
        IO.puts("        Byte #{idx}: expected #{inspect(e)}, got #{inspect(g)}")
      end
    end)
  end
end

# Run the diagnostic
ValueRoundTripDiagnostic.run()
