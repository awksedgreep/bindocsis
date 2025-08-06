#!/usr/bin/env elixir

Code.prepend_path("_build/dev/lib/bindocsis/ebin")

defmodule QuickFixtureTest do
  def test_fixtures() do
    fixture_dir = "test/fixtures"

    if File.exists?(fixture_dir) do
      # Find all fixture files - .cm, .bin, whatever exists
      all_files = Path.wildcard("#{fixture_dir}/*") |> Enum.reject(&File.dir?/1)
      IO.puts("Found #{length(all_files)} fixture files")

      # Test first 10 files to see if our fix works
      all_files
      |> Enum.take(10)
      |> Enum.with_index()
      |> Enum.each(fn {file, index} ->
        IO.puts("\n#{index + 1}. Testing #{Path.basename(file)}...")

        case File.read(file) do
          {:ok, binary_data} ->
            case test_round_trip(binary_data) do
              :success -> IO.puts("✅ PASS")
              {:fail, reason} -> IO.puts("❌ FAIL: #{reason}")
            end

          {:error, reason} ->
            IO.puts("❌ File read error: #{reason}")
        end
      end)
    else
      IO.puts("No fixture directory found")
    end
  end

  defp test_round_trip(binary_data) do
    try do
      # Round-trip test
      case Bindocsis.convert(binary_data, from: :binary, to: :json) do
        {:ok, json} ->
          case Bindocsis.convert(json, from: :json, to: :binary) do
            {:ok, result} ->
              # Allow for terminator differences
              if result == binary_data or result == binary_data <> <<255>> do
                :success
              else
                {:fail,
                 "binary mismatch (#{byte_size(binary_data)} -> #{byte_size(result)} bytes)"}
              end

            {:error, reason} ->
              {:fail, "json->binary failed: #{reason}"}
          end

        {:error, reason} ->
          {:fail, "binary->json failed: #{reason}"}
      end
    rescue
      e -> {:fail, "exception: #{Exception.message(e)}"}
    end
  end
end

QuickFixtureTest.test_fixtures()
