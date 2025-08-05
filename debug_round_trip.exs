#!/usr/bin/env elixir

# Debug script to trace the round-trip conversion issue

Mix.install([{:jason, "~> 1.4"}])

defmodule RoundTripDebug do
  def debug_conversion() do
    IO.puts("=== Debugging Round-Trip Conversion ===")
    
    # Original binary from the failing test
    original = <<3, 1, 1, 18, 1, 0>>
    IO.puts("Original binary: #{inspect(original, base: :hex)}")
    IO.puts("Original binary parsed as TLVs:")
    IO.puts("  TLV 3: length=1, value=1")
    IO.puts("  TLV 18: length=1, value=0")
    
    # Step 1: Binary -> JSON
    IO.puts("\n1. Converting binary to JSON...")
    {:ok, json} = Bindocsis.convert(original, from: :binary, to: :json)
    IO.puts("JSON result:")
    IO.puts(json)
    
    # Let's also parse the JSON to see the structure
    {:ok, parsed_json} = Jason.decode(json)
    IO.puts("\nParsed JSON structure:")
    IO.inspect(parsed_json, limit: :infinity)
    
    # Step 2: JSON -> Binary
    IO.puts("\n2. Converting JSON back to binary...")
    {:ok, back_to_binary} = Bindocsis.convert(json, from: :json, to: :binary)
    IO.puts("Result binary: #{inspect(back_to_binary, base: :hex)}")
    
    # Expected vs actual
    expected = <<3, 1, 1, 18, 1, 0, 255>>
    IO.puts("\nComparison:")
    IO.puts("Expected: #{inspect(expected, base: :hex)}")
    IO.puts("Actual:   #{inspect(back_to_binary, base: :hex)}")
    IO.puts("Match: #{back_to_binary == expected}")
    
    # Let's also parse the actual result to see what TLVs it contains
    IO.puts("\nParsing actual result:")
    case Bindocsis.parse(back_to_binary, format: :binary) do
      {:ok, tlvs} ->
        Enum.each(tlvs, fn tlv ->
          IO.puts("  TLV #{tlv.type}: length=#{tlv.length}, value=#{inspect(tlv.value, base: :hex)}")
        end)
      {:error, reason} ->
        IO.puts("  Error parsing: #{inspect(reason)}")
    end
  end
end

# Add the project to the path so we can use the modules
Code.prepend_path("_build/dev/lib/bindocsis/ebin")

# Run the debug function
RoundTripDebug.debug_conversion()
