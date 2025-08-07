# Test power quarter dB fix

fixture = "test/fixtures/StaticMulticastSession.cm"

case File.read(fixture) do
  {:ok, binary_data} ->
    case Bindocsis.convert(binary_data, from: :binary, to: :json) do
      {:ok, json_output} ->
        IO.puts("✓ Binary -> JSON succeeded")
        
        case Bindocsis.convert(json_output, from: :json, to: :binary) do
          {:ok, _} ->
            IO.puts("✅ JSON -> Binary round-trip SUCCESSFUL")
          {:error, reason} ->
            IO.puts("❌ JSON -> Binary failed: #{reason}")
        end
      {:error, reason} ->
        IO.puts("❌ Binary -> JSON failed: #{reason}")
    end
  {:error, reason} ->
    IO.puts("❌ File read failed: #{reason}")
end