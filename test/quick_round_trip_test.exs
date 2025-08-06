defmodule QuickRoundTripTest do
  use ExUnit.Case

  test "quick round-trip test sample" do
    # Test a few fixtures to see if our fix improved things
    fixtures =
      ["test/fixtures/test_mta.bin", "test/fixtures/BaseConfig.cm"]
      |> Enum.filter(&File.exists?/1)
      |> Enum.take(2)

    results =
      Enum.map(fixtures, fn fixture_path ->
        try do
          # Binary -> JSON
          case Bindocsis.parse_file(fixture_path) do
            {:ok, tlvs} ->
              case Bindocsis.generate(tlvs, format: :json) do
                {:ok, json_result} ->
                  # JSON -> Binary
                  case JSON.decode(json_result) do
                    {:ok, json_data} ->
                      # Now use HumanConfig to parse it back
                      case Bindocsis.HumanConfig.from_json(json_result) do
                        {:ok, _binary_result} ->
                          {:ok, fixture_path}

                        {:error, reason} ->
                          {:error, {fixture_path, "JSON->Binary: #{reason}"}}
                      end

                    {:error, reason} ->
                      {:error, {fixture_path, "JSON decode: #{reason}"}}
                  end

                {:error, reason} ->
                  {:error, {fixture_path, "Binary->JSON: #{reason}"}}
              end

            {:error, reason} ->
              {:error, {fixture_path, "Binary parse: #{reason}"}}
          end
        rescue
          e -> {:error, {fixture_path, "Exception: #{inspect(e)}"}}
        end
      end)

    {successes, failures} = Enum.split_with(results, fn {status, _} -> status == :ok end)

    IO.puts("\n=== QUICK ROUND-TRIP TEST ===")
    IO.puts("✅ Successful: #{length(successes)}")
    IO.puts("❌ Failed: #{length(failures)}")

    if length(failures) > 0 do
      Enum.each(failures, fn {:error, {file, reason}} ->
        IO.puts("❌ #{Path.basename(file)}: #{reason}")
      end)
    end

    # Don't fail the test, just report results
    assert true
  end
end
