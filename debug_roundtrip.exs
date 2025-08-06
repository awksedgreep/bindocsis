#!/usr/bin/env elixir

# Load dependencies
Mix.install([
  {:bindocsis, path: Path.expand(".", __DIR__)},
  {:jason, "~> 1.4"}
])

fixture_file = "test/fixtures/test_mta.bin"
IO.puts("Testing fixture: #{fixture_file}")

# Step 1: Parse binary to JSON
case Bindocsis.parse_file(fixture_file) do
  {:ok, tlvs} ->
    case Bindocsis.generate(tlvs, format: :json) do
      {:ok, json_result} ->
        File.write!("/tmp/test.json", json_result)
        IO.puts("✅ Binary -> JSON successful")

        # Step 2: Parse JSON back to binary
        case Bindocsis.parse_file("/tmp/test.json", format: :json) do
          {:ok, parsed_tlvs} ->
            case Bindocsis.generate(parsed_tlvs, format: :binary) do
              {:ok, binary_result} ->
                File.write!("/tmp/test.bin", binary_result)
                IO.puts("✅ JSON -> Binary successful")
                IO.puts("Round-trip completed successfully!")

              {:error, reason} ->
                IO.puts("❌ JSON -> Binary failed: #{reason}")
            end

          {:error, reason} ->
            IO.puts("❌ JSON parsing failed: #{reason}")
        end

      {:error, reason} ->
        IO.puts("❌ Binary -> JSON failed: #{reason}")
    end

  {:error, reason} ->
    IO.puts("❌ Binary parsing failed: #{reason}")
end
