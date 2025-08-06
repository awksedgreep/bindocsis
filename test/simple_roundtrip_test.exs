defmodule SimpleRoundtripTest do
  use ExUnit.Case
  require Logger

  test "debug first fixture with detailed error info" do
    # Get the first fixture
    fixture_files =
      Path.wildcard("test/fixtures/*.{cm,bin}")
      |> Enum.reject(&String.ends_with?(&1, ".cmbroken"))
      |> Enum.sort()

    fixture_file = List.first(fixture_files)
    IO.puts("Testing fixture: #{fixture_file}")

    # Step 1: Parse binary to JSON using our API
    case Bindocsis.parse_file(fixture_file) do
      {:ok, tlvs} ->
        IO.puts("✅ Binary parsing successful")

        case Bindocsis.generate(tlvs, format: :json) do
          {:ok, json_result} ->
            IO.puts("✅ JSON generation successful")

            # Write JSON to file so we can examine it
            File.write!("/tmp/debug_output.json", json_result)

            # Step 2: Parse JSON back using our API
            case Bindocsis.parse_file("/tmp/debug_output.json", format: :json) do
              {:ok, parsed_tlvs} ->
                IO.puts("✅ JSON parsing successful")

                case Bindocsis.generate(parsed_tlvs, format: :binary) do
                  {:ok, binary_result} ->
                    IO.puts("✅ Binary generation successful")
                    IO.puts("Round-trip completed successfully!")

                  {:error, reason} ->
                    IO.puts("❌ JSON -> Binary failed: #{reason}")

                    # Let's examine the JSON data
                    json_data = JSON.decode!(json_result)
                    IO.puts("\n=== EXAMINING JSON STRUCTURE ===")

                    # Look at the first few TLVs
                    tlvs_data = Map.get(json_data, "tlvs", [])
                    IO.puts("Total TLVs: #{length(tlvs_data)}")

                    # Find service flow TLVs (type 24)
                    service_flows = Enum.filter(tlvs_data, &(Map.get(&1, "type") == 24))
                    IO.puts("Service flow TLVs found: #{length(service_flows)}")

                    if length(service_flows) > 0 do
                      sf = List.first(service_flows)
                      IO.puts("\n=== FIRST SERVICE FLOW TLV ===")
                      IO.inspect(sf, limit: :infinity)
                    end

                    flunk("Binary generation failed: #{reason}")
                end

              {:error, reason} ->
                IO.puts("❌ JSON parsing failed: #{reason}")

                # Show first part of JSON for debugging
                json_preview = String.slice(json_result, 0, 1000)
                IO.puts("\n=== JSON PREVIEW (first 1000 chars) ===")
                IO.puts(json_preview)

                flunk("JSON parsing failed: #{reason}")
            end

          {:error, reason} ->
            IO.puts("❌ JSON generation failed: #{reason}")
            flunk("JSON generation failed: #{reason}")
        end

      {:error, reason} ->
        IO.puts("❌ Binary parsing failed: #{reason}")
        flunk("Binary parsing failed: #{reason}")
    end
  end
end
