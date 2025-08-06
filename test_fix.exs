#!/usr/bin/env elixir

Mix.install([
  {:bindocsis, path: Path.expand(".", __DIR__)},
  {:jason, "~> 1.4"}
])

# Test our fix by running a simple round-trip
fixtures =
  Path.wildcard("test/fixtures/*.{cm,bin}")
  |> Enum.reject(&String.ends_with?(&1, ".cmbroken"))
  # Test first 10 fixtures
  |> Enum.take(10)

IO.puts("Testing #{length(fixtures)} fixtures with our fix...")

results =
  Enum.map(fixtures, fn fixture_path ->
    try do
      # Step 1: Parse binary to JSON
      case Bindocsis.parse_file(fixture_path) do
        {:ok, tlvs} ->
          case Bindocsis.generate(tlvs, format: :json) do
            {:ok, json_result} ->
              # Step 2: Parse JSON back to binary
              case Bindocsis.parse_file_from_string(json_result, format: :json) do
                {:ok, parsed_tlvs} ->
                  case Bindocsis.generate(parsed_tlvs, format: :binary) do
                    {:ok, _binary_result} ->
                      {:ok, fixture_path}

                    {:error, reason} ->
                      {:error, {fixture_path, "JSON -> Binary failed: #{reason}"}}
                  end

                {:error, reason} ->
                  {:error, {fixture_path, "JSON parsing failed: #{reason}"}}
              end

            {:error, reason} ->
              {:error, {fixture_path, "Binary -> JSON failed: #{reason}"}}
          end

        {:error, reason} ->
          {:error, {fixture_path, "Binary parsing failed: #{reason}"}}
      end
    rescue
      e -> {:error, {fixture_path, "Exception: #{inspect(e)}"}}
    end
  end)

# Count successes and failures
{successes, failures} = Enum.split_with(results, fn {status, _} -> status == :ok end)

IO.puts("\n=== ROUND-TRIP TEST RESULTS ===")
IO.puts("✅ Successful round-trips: #{length(successes)}")
IO.puts("❌ Failed round-trips: #{length(failures)}")

if length(failures) > 0 do
  IO.puts("\n=== FIRST FEW FAILURES ===")

  failures
  |> Enum.take(3)
  |> Enum.each(fn {:error, {file, reason}} ->
    IO.puts("❌ #{Path.basename(file)}: #{reason}")
  end)
end

success_rate = (length(successes) / length(results) * 100) |> Float.round(1)
IO.puts("\n📊 Success Rate: #{success_rate}% (#{length(successes)}/#{length(results)})")

IO.puts("\n=== FIX VERIFICATION ===")

if success_rate > 50.0 do
  IO.puts("🎉 Significant improvement! Our fix is working.")
else
  IO.puts("⚠️  Still issues to resolve.")
end
