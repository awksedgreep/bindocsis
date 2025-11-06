defmodule DebugJsonEncodingTest do
  use ExUnit.Case

  test "debug JSON encoding of binary values" do
    # Original value
    original_value = <<0x12, 0x34, 0x56, 0x78>>
    IO.puts("\n=== ORIGINAL ===")
    IO.puts("Binary: #{inspect(original_value, limit: :infinity)}")
    IO.puts("Hex: #{Base.encode16(original_value)}")
    IO.puts("Bytes: #{inspect(:binary.bin_to_list(original_value))}")

    # Create TLV
    tlv = %{type: 1, length: 4, value: original_value}

    # Generate JSON
    {:ok, json_string} = Bindocsis.Generators.JsonGenerator.generate([tlv])
    IO.puts("\n=== JSON ===")
    IO.puts(json_string)

    # Parse JSON back
    {:ok, parsed_tlvs} = Bindocsis.parse(json_string, format: :json)
    IO.puts("\n=== PARSED FROM JSON ===")
    [parsed_tlv] = parsed_tlvs
    IO.puts("Binary: #{inspect(parsed_tlv.value, limit: :infinity)}")
    IO.puts("Hex: #{Base.encode16(parsed_tlv.value)}")
    IO.puts("Bytes: #{inspect(:binary.bin_to_list(parsed_tlv.value))}")

    # Compare
    if original_value == parsed_tlv.value do
      IO.puts("\n✅ Values match!")
    else
      IO.puts("\n❌ Values DON'T match!")
      IO.puts("Expected: #{inspect(original_value)}")
      IO.puts("Got: #{inspect(parsed_tlv.value)}")

      # Find differences
      orig_list = :binary.bin_to_list(original_value)
      parsed_list = :binary.bin_to_list(parsed_tlv.value)

      Enum.zip(orig_list, parsed_list)
      |> Enum.with_index()
      |> Enum.each(fn {{o, p}, idx} ->
        if o != p do
          IO.puts(
            "Byte #{idx}: #{o} (0x#{Integer.to_string(o, 16)}) -> #{p} (0x#{Integer.to_string(p, 16)})"
          )
        end
      end)
    end
  end
end
