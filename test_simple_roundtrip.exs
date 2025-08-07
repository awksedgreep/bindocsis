#!/usr/bin/env elixir

defmodule SimpleRoundTripTest do
  def test_all_fixtures do
    fixtures = Path.wildcard("test/fixtures/*.cm")
    
    json_success = 0
    json_total = 0
    yaml_success = 0
    yaml_total = 0
    
    IO.puts("\n=== Testing Round-Trips ===")
    
    Enum.each(fixtures, fn fixture ->
      basename = Path.basename(fixture)
      
      # Test JSON
      json_total = json_total + 1
      case test_json_round_trip(fixture) do
        :ok -> 
          json_success = json_success + 1
          IO.puts("✅ JSON: #{basename}")
        {:error, reason} ->
          IO.puts("❌ JSON: #{basename} - #{reason}")
      end
      
      # Test YAML
      yaml_total = yaml_total + 1
      case test_yaml_round_trip(fixture) do
        :ok -> 
          yaml_success = yaml_success + 1
          IO.puts("✅ YAML: #{basename}")
        {:error, reason} ->
          IO.puts("❌ YAML: #{basename} - #{reason}")
      end
    end)
    
    IO.puts("\n=== Summary ===")
    json_rate = Float.round(json_success / json_total * 100, 1)
    yaml_rate = Float.round(yaml_success / yaml_total * 100, 1)
    IO.puts("JSON Success Rate: #{json_rate}% (#{json_success}/#{json_total})")
    IO.puts("YAML Success Rate: #{yaml_rate}% (#{yaml_success}/#{yaml_total})")
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
              {:error, "Parse: #{inspect(reason)}"}
          end
        {:error, reason} ->
          {:error, "Gen: #{inspect(reason)}"}
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
              {:error, "Parse: #{inspect(reason)}"}
          end
        {:error, reason} ->
          {:error, "Gen: #{inspect(reason)}"}
      end
    rescue
      e -> {:error, "Exception: #{Exception.message(e)}"}
    end
  end
end

SimpleRoundTripTest.test_all_fixtures()