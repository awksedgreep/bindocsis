# Debug YAML round-trip structure mismatch

fixture = "test/fixtures/BaseConfig.cm"

case File.read(fixture) do
  {:ok, binary_data} ->
    IO.puts("=== ORIGINAL BINARY TO JSON ===")
    case Bindocsis.convert(binary_data, from: :binary, to: :json) do
      {:ok, original_json} ->
        case Bindocsis.convert(binary_data, from: :binary, to: :yaml) do
          {:ok, yaml_output} ->
            IO.puts("\n=== YAML OUTPUT ===")
            IO.puts(yaml_output |> String.split("\n") |> Enum.take(30) |> Enum.join("\n"))
            
            case Bindocsis.convert(yaml_output, from: :yaml, to: :binary) do
              {:ok, roundtrip_binary} ->
                case Bindocsis.convert(roundtrip_binary, from: :binary, to: :json) do
                  {:ok, roundtrip_json} ->
                    IO.puts("\n=== STRUCTURE COMPARISON ===")
                    original_data = JSON.decode!(original_json)
                    roundtrip_data = JSON.decode!(roundtrip_json)
                    
                    original_tlvs = original_data["tlvs"]
                    roundtrip_tlvs = roundtrip_data["tlvs"]
                    
                    IO.puts("Original TLV count: #{length(original_tlvs)}")
                    IO.puts("Roundtrip TLV count: #{length(roundtrip_tlvs)}")
                    
                    IO.puts("\n=== FIRST TLV COMPARISON ===")
                    if length(original_tlvs) > 0 and length(roundtrip_tlvs) > 0 do
                      IO.puts("Original first TLV:")
                      IO.inspect(Enum.at(original_tlvs, 0), pretty: true)
                      IO.puts("\nRoundtrip first TLV:")
                      IO.inspect(Enum.at(roundtrip_tlvs, 0), pretty: true)
                    end
                    
                    if length(original_tlvs) > 1 and length(roundtrip_tlvs) > 1 do
                      IO.puts("\n=== SECOND TLV (Likely TLV 24) ===")
                      IO.puts("Original second TLV:")
                      IO.inspect(Enum.at(original_tlvs, 1), pretty: true)
                      IO.puts("\nRoundtrip second TLV:")
                      IO.inspect(Enum.at(roundtrip_tlvs, 1), pretty: true)
                    end
                  {:error, reason} ->
                    IO.puts("❌ Roundtrip JSON conversion failed: #{reason}")
                end
              {:error, reason} ->
                IO.puts("❌ YAML -> Binary conversion failed: #{reason}")
            end
          {:error, reason} ->
            IO.puts("❌ Binary -> YAML conversion failed: #{reason}")
        end
      {:error, reason} ->
        IO.puts("❌ Binary -> JSON conversion failed: #{reason}")
    end
  {:error, reason} ->
    IO.puts("❌ File read failed: #{reason}")
end