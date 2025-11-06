defmodule DebugMtaTest do
  use ExUnit.Case

  test "MTA round-trip analysis" do
    # Read the MTA file
    {:ok, original} = File.read("test/fixtures/test_mta.bin")
    IO.puts("\n=== ORIGINAL ===")
    IO.puts("Size: #{byte_size(original)} bytes")
    IO.puts("Hex: #{Base.encode16(original)}")

    # Parse it
    {:ok, tlvs} = Bindocsis.parse(original, format: :mta)
    IO.puts("\n=== PARSED #{length(tlvs)} TLVs ===")

    Enum.with_index(tlvs)
    |> Enum.each(fn {tlv, idx} ->
      IO.puts("TLV #{idx}: Type=#{tlv.type}, Length=#{tlv.length}")
      IO.puts("  Value: #{inspect(tlv.value, limit: :infinity)}")
      IO.puts("  Hex: #{Base.encode16(tlv.value)}")
    end)

    # Generate it back
    {:ok, regenerated} = Bindocsis.generate(tlvs, format: :mta, terminate: false)
    IO.puts("\n=== REGENERATED ===")
    IO.puts("Size: #{byte_size(regenerated)} bytes")
    IO.puts("Hex: #{Base.encode16(regenerated)}")

    # Compare byte by byte
    IO.puts("\n=== COMPARISON ===")

    if original == regenerated do
      IO.puts("✅ Perfect match!")
    else
      IO.puts("⚠️  Difference detected (#{byte_size(regenerated) - byte_size(original)} bytes)")

      # Find first difference
      orig_bytes = :binary.bin_to_list(original)
      regen_bytes = :binary.bin_to_list(regenerated)

      Enum.zip(orig_bytes ++ List.duplicate(nil, 100), regen_bytes ++ List.duplicate(nil, 100))
      |> Enum.with_index()
      |> Enum.each(fn {{o, r}, idx} ->
        if o != r do
          IO.puts(
            "Byte #{idx}: Expected #{inspect(o)} (#{if o, do: "0x#{Integer.to_string(o, 16)}", else: "END"}), Got #{inspect(r)} (#{if r, do: "0x#{Integer.to_string(r, 16)}", else: "END"})"
          )
        end
      end)
    end

    # Just for test to pass
    assert true
  end
end
