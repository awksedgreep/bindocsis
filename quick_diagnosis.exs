#!/usr/bin/env elixir

# Quick test to identify root cause of round-trip failures

defmodule QuickDiagnosis do
  def test_fixtures() do
    IO.puts("=== Quick Round-Trip Diagnosis ===")

    # Test just a few fixtures to see the specific errors
    fixture_dir = "test/fixtures"

    fixtures =
      if File.exists?(fixture_dir) do
        File.ls!(fixture_dir)
        |> Enum.filter(&String.ends_with?(&1, ".bin"))
        # Just test 3 files
        |> Enum.take(3)
        |> Enum.map(&Path.join(fixture_dir, &1))
      else
        []
      end

    IO.puts("Testing #{length(fixtures)} fixtures...")

    results =
      Enum.map(fixtures, fn fixture_path ->
        IO.puts("\nTesting: #{Path.basename(fixture_path)}")
        test_single_fixture(fixture_path)
      end)

    {successes, failures} = Enum.split_with(results, fn {status, _} -> status == :ok end)

    IO.puts("\n=== RESULTS ===")
    IO.puts("✅ Successful: #{length(successes)}")
    IO.puts("❌ Failed: #{length(failures)}")

    Enum.each(failures, fn {:error, {file, reason}} ->
      IO.puts("❌ #{Path.basename(file)}: #{reason}")
    end)
  end

  defp test_single_fixture(fixture_path) do
    try do
      # Step 1: Parse binary to JSON
      case Bindocsis.parse_file(fixture_path) do
        {:ok, tlvs} ->
          IO.puts("  ✓ Binary parsing successful")

          # Step 2: Generate JSON
          case Bindocsis.generate(tlvs, format: :json) do
            {:ok, json_str} ->
              IO.puts("  ✓ JSON generation successful")

              # Step 3: Parse JSON back
              case Bindocsis.parse(json_str, format: :json) do
                {:ok, parsed_tlvs} ->
                  IO.puts("  ✓ JSON parsing successful")

                  # Step 4: Generate binary
                  case Bindocsis.generate(parsed_tlvs, format: :binary) do
                    {:ok, _binary} ->
                      IO.puts("  ✓ Binary generation successful")
                      {:ok, fixture_path}

                    {:error, reason} ->
                      IO.puts("  ✗ Binary generation failed: #{reason}")
                      {:error, {fixture_path, "JSON->Binary: #{reason}"}}
                  end

                {:error, reason} ->
                  IO.puts("  ✗ JSON parsing failed: #{reason}")
                  {:error, {fixture_path, "JSON parse: #{reason}"}}
              end

            {:error, reason} ->
              IO.puts("  ✗ JSON generation failed: #{reason}")
              {:error, {fixture_path, "Binary->JSON: #{reason}"}}
          end

        {:error, reason} ->
          IO.puts("  ✗ Binary parsing failed: #{reason}")
          {:error, {fixture_path, "Binary parse: #{reason}"}}
      end
    rescue
      e ->
        error_msg = "Exception: #{Exception.message(e)}"
        IO.puts("  ✗ #{error_msg}")
        {:error, {fixture_path, error_msg}}
    end
  end
end

# Add the project to the code path
Code.prepend_path("_build/dev/lib/bindocsis/ebin")

# Run the diagnosis
QuickDiagnosis.test_fixtures()
