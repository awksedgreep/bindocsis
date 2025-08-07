# Debug boolean value error

fixture = "test/fixtures/TLV_24_last_before_43.cm"

case File.read(fixture) do
  {:ok, binary_data} ->
    case Bindocsis.convert(binary_data, from: :binary, to: :json) do
      {:ok, json_output} ->
        IO.puts("=== JSON GENERATED ===")
        
        # Try converting back to see the exact error
        case Bindocsis.convert(json_output, from: :json, to: :binary) do
          {:ok, _} ->
            IO.puts("✓ JSON -> Binary conversion succeeded")
          {:error, reason} ->
            IO.puts("❌ JSON -> Binary conversion failed:")
            IO.puts(reason)
            
            # Show a sample of the JSON to see the problematic values
            IO.puts("\n=== SAMPLE JSON ===")
            IO.puts(String.slice(json_output, 0, 500) <> "...")
        end
      {:error, reason} ->
        IO.puts("❌ Binary -> JSON failed: #{reason}")
    end
  {:error, reason} ->
    IO.puts("❌ File read failed: #{reason}")
end