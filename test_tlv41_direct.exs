# Test TLV41 directly to see the boolean issue

fixture = "test/fixtures/TLV41_DsChannelList.cm"

case File.read(fixture) do
  {:ok, binary_data} ->
    case Bindocsis.convert(binary_data, from: :binary, to: :json) do
      {:ok, json_output} ->
        IO.puts("✓ Binary -> JSON conversion succeeded")
        
        # Show the first 2000 chars of JSON to see the structure
        IO.puts("=== JSON SAMPLE ===")
        IO.puts(String.slice(json_output, 0, 2000) <> "...")
        
        case Bindocsis.convert(json_output, from: :json, to: :binary) do
          {:ok, _} ->
            IO.puts("✅ JSON -> Binary conversion succeeded")
          {:error, reason} ->
            IO.puts("❌ JSON -> Binary conversion failed:")
            IO.puts(reason)
        end
      {:error, reason} ->
        IO.puts("❌ Binary -> JSON failed: #{reason}")
    end
  {:error, reason} ->
    IO.puts("❌ File read failed: #{reason}")
end