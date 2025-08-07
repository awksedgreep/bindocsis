# Simple frequency test

fixture = "test/fixtures/TLV_22_43_5_2_1.cm"

case File.read(fixture) do
  {:ok, binary_data} ->
    case Bindocsis.convert(binary_data, from: :binary, to: :json) do
      {:ok, json_output} ->
        IO.puts("✓ Binary -> JSON succeeded")
        
        case Bindocsis.convert(json_output, from: :json, to: :binary) do
          {:ok, _} ->
            IO.puts("✅ JSON -> Binary succeeded") 
          {:error, reason} ->
            IO.puts("❌ JSON -> Binary failed:")
            IO.puts(reason)
            
            # Show sample of JSON to see the frequency values
            IO.puts("\\n=== SAMPLE JSON (first 1000 chars) ===")
            IO.puts(String.slice(json_output, 0, 1000) <> "...")
        end
      {:error, reason} ->
        IO.puts("❌ Binary -> JSON failed: #{reason}")
    end
  {:error, reason} ->
    IO.puts("❌ File read failed: #{reason}")
end