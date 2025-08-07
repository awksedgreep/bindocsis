#!/usr/bin/env elixir

# Comprehensive test to measure success rates

defmodule ComprehensiveTest do
  def test_fixtures do
    json_fixtures = Path.wildcard("test/fixtures/*.cm") |> Enum.take(50)
    yaml_fixtures = Path.wildcard("test/fixtures/*.cm") |> Enum.take(25)
    
    IO.puts("\n=== JSON Round-trip Testing ===")
    json_results = test_json_round_trips(json_fixtures)
    
    IO.puts("\n=== YAML Round-trip Testing ===")
    yaml_results = test_yaml_round_trips(yaml_fixtures)
    
    IO.puts("\n=== Summary ===")
    IO.puts("JSON Success Rate: #{json_results.success_rate}% (#{json_results.success}/#{json_results.total})")
    IO.puts("YAML Success Rate: #{yaml_results.success_rate}% (#{yaml_results.success}/#{yaml_results.total})")
  end
  
  defp test_json_round_trips(fixtures) do
    results = Enum.map(fixtures, fn fixture ->
      case test_json_round_trip(fixture) do
        :ok -> {:ok, fixture}
        {:error, _reason} -> {:error, fixture}
      end
    end)
    
    success_count = Enum.count(results, fn {status, _} -> status == :ok end)
    total = length(results)
    
    %{
      success: success_count,
      total: total,
      success_rate: Float.round(success_count / total * 100, 1)
    }
  end
  
  defp test_yaml_round_trips(fixtures) do
    results = Enum.map(fixtures, fn fixture ->
      case test_yaml_round_trip(fixture) do
        :ok -> {:ok, fixture}
        {:error, _reason} -> {:error, fixture}
      end
    end)
    
    success_count = Enum.count(results, fn {status, _} -> status == :ok end)
    total = length(results)
    
    %{
      success: success_count,
      total: total,
      success_rate: Float.round(success_count / total * 100, 1)
    }
  end
  
  defp test_json_round_trip(fixture_path) do
    try do
      binary = File.read!(fixture_path)
      
      case Bindocsis.HumanConfig.to_json(binary) do
        {:ok, json_content} ->
          case Bindocsis.HumanConfig.from_json(json_content) do
            {:ok, _regenerated_binary} ->
              :ok
            {:error, reason} ->
              {:error, "JSON parse failed: #{reason}"}
          end
        {:error, reason} ->
          {:error, "JSON generation failed: #{reason}"}
      end
    rescue
      e -> {:error, "Exception: #{Exception.message(e)}"}
    end
  end
  
  defp test_yaml_round_trip(fixture_path) do
    try do
      binary = File.read!(fixture_path)
      
      case Bindocsis.HumanConfig.to_yaml(binary) do
        {:ok, yaml_content} ->
          case Bindocsis.HumanConfig.from_yaml(yaml_content) do
            {:ok, _regenerated_binary} ->
              :ok
            {:error, reason} ->
              {:error, "YAML parse failed: #{reason}"}
          end
        {:error, reason} ->
          {:error, "YAML generation failed: #{reason}"}
      end
    rescue
      e -> {:error, "Exception: #{Exception.message(e)}"}
    end
  end
end

ComprehensiveTest.test_fixtures()