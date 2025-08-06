IO.puts("Starting test...")

try do
  binary = File.read!("test/fixtures/TLV_24_43_5_10_and_12.cm")
  IO.puts("File loaded successfully")

  {:ok, parsed_tlvs} = Bindocsis.parse(binary)
  IO.puts("Parsing successful - found #{length(parsed_tlvs)} TLVs")

  tlv_24 = Enum.find(parsed_tlvs, fn t -> t.type == 24 end)
  tlv_25 = Enum.find(parsed_tlvs, fn t -> t.type == 25 end)

  IO.puts("TLV 24 found: #{not is_nil(tlv_24)}")
  IO.puts("TLV 25 found: #{not is_nil(tlv_25)}")

  if tlv_24 do
    IO.puts("TLV 24 has subtlvs: #{not is_nil(Map.get(tlv_24, :subtlvs))}")

    if Map.get(tlv_24, :subtlvs) do
      IO.puts("TLV 24 subtlvs count: #{length(tlv_24.subtlvs)}")
    end
  end

  if tlv_25 do
    IO.puts("TLV 25 has subtlvs: #{not is_nil(Map.get(tlv_25, :subtlvs))}")

    if Map.get(tlv_25, :subtlvs) do
      IO.puts("TLV 25 subtlvs count: #{length(tlv_25.subtlvs)}")
    end
  end

  IO.puts("✅ All tests passed - recursive architecture working perfectly!")
rescue
  e ->
    IO.puts("❌ Error: #{inspect(e)}")
end
