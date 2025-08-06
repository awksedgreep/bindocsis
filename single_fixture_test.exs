#!/usr/bin/env elixir

# Test a single known fixture to identify the specific error
defmodule SingleFixtureTest do
  def test_one_fixture() do
    IO.puts("=== Testing Single Fixture for Root Cause ===")

    # Find any binary fixture
    fixture_path =
      case File.ls("test/fixtures") do
        {:ok, files} ->
          files
          |> Enum.find(&String.ends_with?(&1, ".bin"))
          |> case do
            nil -> nil
            file -> Path.join("test/fixtures", file)
          end

        _ ->
          nil
      end

    if fixture_path && File.exists?(fixture_path) do
      IO.puts("Testing fixture: #{fixture_path}")

      try do
        # Step 1: Parse binary → JSON
        case Bindocsis.parse_file(fixture_path) do
          {:ok, tlvs} ->
            IO.puts("✓ Step 1: Binary parsing successful (#{length(tlvs)} TLVs)")

            # Show some TLV info
            IO.puts("TLV types found: #{Enum.map(tlvs, & &1.type) |> Enum.uniq() |> Enum.sort()}")

            # Step 2: Generate JSON
            case Bindocsis.generate(tlvs, format: :json) do
              {:ok, json_str} ->
                IO.puts("✓ Step 2: JSON generation successful")

                # Show a sample of the JSON structure
                case Jason.decode(json_str) do
                  {:ok, json_data} ->
                    tlv_sample = get_in(json_data, ["tlvs"]) |> Enum.take(2)
                    IO.puts("JSON sample (first 2 TLVs):")
                    IO.inspect(tlv_sample, limit: :infinity)

                    # Step 3: Parse JSON back to TLVs
                    case Bindocsis.parse(json_str, format: :json) do
                      {:ok, parsed_tlvs} ->
                        IO.puts("✓ Step 3: JSON parsing successful (#{length(parsed_tlvs)} TLVs)")

                        # Step 4: Generate binary
                        case Bindocsis.generate(parsed_tlvs, format: :binary) do
                          {:ok, _binary} ->
                            IO.puts("✓ Step 4: Binary generation successful")
                            IO.puts("🎉 ROUND-TRIP SUCCESSFUL!")

                          {:error, reason} ->
                            IO.puts("✗ Step 4 FAILED: Binary generation error")
                            IO.puts("Error: #{reason}")
                            IO.puts("This is likely where the 138 failures occur!")
                        end

                      {:error, reason} ->
                        IO.puts("✗ Step 3 FAILED: JSON parsing error")
                        IO.puts("Error: #{reason}")
                    end

                  {:error, reason} ->
                    IO.puts("✗ JSON decode failed: #{reason}")
                end

              {:error, reason} ->
                IO.puts("✗ Step 2 FAILED: JSON generation error")
                IO.puts("Error: #{reason}")
            end

          {:error, reason} ->
            IO.puts("✗ Step 1 FAILED: Binary parsing error")
            IO.puts("Error: #{reason}")
        end
      rescue
        e ->
          IO.puts("✗ EXCEPTION: #{Exception.message(e)}")
          IO.puts("Stacktrace:")
          IO.puts(Exception.format_stacktrace(__STACKTRACE__))
      end
    else
      IO.puts("No fixture file found to test")
    end
  end
end

SingleFixtureTest.test_one_fixture()
