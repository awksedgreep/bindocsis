defmodule DebugMtaJsonRoundtripTest do
  use ExUnit.Case

  test "debug MTA JSON round-trip" do
    {:ok, original_binary} = File.read("test/fixtures/test_mta.bin")
    IO.puts("\n=== ORIGINAL BINARY ===")
    IO.puts("Size: #{byte_size(original_binary)} bytes")
    IO.puts("Hex: #{Base.encode16(original_binary)}")

    {:ok, tlvs} = Bindocsis.parse(original_binary, format: :mta)
    IO.puts("\n=== PARSED TLVs ===")
    IO.puts("Count: #{length(tlvs)}")

    Enum.each(tlvs, fn tlv ->
      IO.puts("  Type #{tlv.type}: length=#{tlv.length}, value_hex=#{Base.encode16(tlv.value)}")
    end)

    {:ok, json_string} = Bindocsis.generate(tlvs, format: :json)
    IO.puts("\n=== JSON ===")
    IO.puts(String.slice(json_string, 0, 500) <> "...")

    {:ok, tlvs_from_json} = Bindocsis.parse(json_string, format: :json)
    IO.puts("\n=== PARSED FROM JSON ===")
    IO.puts("Count: #{length(tlvs_from_json)}")

    Enum.each(tlvs_from_json, fn tlv ->
      IO.puts("  Type #{tlv.type}: length=#{tlv.length}, value_hex=#{Base.encode16(tlv.value)}")
    end)

    {:ok, regenerated_binary} = Bindocsis.generate(tlvs_from_json, format: :mta, terminate: false)
    IO.puts("\n=== REGENERATED BINARY ===")
    IO.puts("Size: #{byte_size(regenerated_binary)} bytes")
    IO.puts("Hex: #{Base.encode16(regenerated_binary)}")

    IO.puts("\n=== COMPARISON ===")
    IO.puts("Original:    #{Base.encode16(original_binary)}")
    IO.puts("Regenerated: #{Base.encode16(regenerated_binary)}")
    IO.puts("Match: #{original_binary == regenerated_binary}")

    if original_binary != regenerated_binary do
      # Find byte differences
      orig_bytes = :binary.bin_to_list(original_binary)
      regen_bytes = :binary.bin_to_list(regenerated_binary)

      min_len = min(length(orig_bytes), length(regen_bytes))

      Enum.zip(Enum.slice(orig_bytes, 0, min_len), Enum.slice(regen_bytes, 0, min_len))
      |> Enum.with_index()
      |> Enum.filter(fn {{o, r}, _idx} -> o != r end)
      |> Enum.each(fn {{o, r}, idx} ->
        IO.puts("Byte #{idx}: 0x#{Integer.to_string(o, 16)} -> 0x#{Integer.to_string(r, 16)}")
      end)
    end
  end
end
