#!/usr/bin/env elixir

binary = File.read!("test/fixtures/TLV_22_43_1_CMLoadBalancingPolicyID.cm")

# Try full JSON generation
case Bindocsis.HumanConfig.to_json(binary) do
  {:ok, json_string} ->
    IO.puts("✅ JSON generation successful")
    
    # Try to parse it
    case JSON.decode(json_string) do
      {:ok, _parsed} ->
        IO.puts("✅ JSON is valid")
      {:error, error} ->
        IO.puts("❌ JSON decode error: #{inspect(error)}")
    end
    
  {:error, reason} ->
    IO.puts("❌ JSON generation failed: #{reason}")
end