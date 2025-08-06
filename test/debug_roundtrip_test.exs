defmodule DebugRoundtripTest do
  use ExUnit.Case
  require Logger

  test "debug single fixture round-trip" do
    fixture_file = "test/fixtures/test_mta.bin"

    # Step 1: Parse binary to JSON
    {:ok, tlvs} = Bindocsis.parse_file(fixture_file)
    {:ok, json_result} = Bindocsis.generate(tlvs, format: :json)

    IO.puts("=== JSON STRUCTURE ===")
    json_data = JSON.decode!(json_result)
    IO.inspect(json_data, limit: :infinity, printable_limit: :infinity)

    File.write!("/tmp/debug_test.json", json_result)
    IO.puts("✅ Binary -> JSON successful")

    # Step 2: Parse JSON back to binary - this is where it should fail
    case Bindocsis.parse_file("/tmp/debug_test.json", format: :json) do
      {:ok, parsed_tlvs} ->
        case Bindocsis.generate(parsed_tlvs, format: :binary) do
          {:ok, binary_result} ->
            File.write!("/tmp/debug_test.bin", binary_result)
            IO.puts("✅ JSON -> Binary successful")

          {:error, reason} ->
            IO.puts("❌ JSON -> Binary failed: #{reason}")
            raise "JSON -> Binary conversion failed: #{reason}"
        end

      {:error, reason} ->
        IO.puts("❌ JSON parsing failed: #{reason}")
        raise "JSON parsing failed: #{reason}"
    end
  end
end
