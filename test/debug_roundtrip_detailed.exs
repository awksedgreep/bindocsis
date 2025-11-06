defmodule DebugRoundtripDetailedTest do
  use ExUnit.Case

  test "detailed frequency round-trip analysis" do
    # Original binary value
    original_binary = <<0x12, 0x34, 0x56, 0x78>>
    original_hz = :binary.decode_unsigned(original_binary)

    IO.puts("\n=== ORIGINAL ===")
    IO.puts("Binary: #{inspect(original_binary)}")
    IO.puts("Hex: #{Base.encode16(original_binary)}")
    IO.puts("Hz value: #{original_hz}")
    IO.puts("MHz value: #{original_hz / 1_000_000}")

    # Create TLV
    tlv = %{type: 1, length: 4, value: original_binary}

    # Generate JSON
    {:ok, json_string} = Bindocsis.Generators.JsonGenerator.generate([tlv])
    IO.puts("\n=== JSON ===")
    IO.puts(json_string)

    # Parse JSON back
    {:ok, parsed_tlvs} = Bindocsis.parse(json_string, format: :json)
    [parsed_tlv] = parsed_tlvs

    parsed_hz = :binary.decode_unsigned(parsed_tlv.value)

    IO.puts("\n=== PARSED ===")
    IO.puts("Binary: #{inspect(parsed_tlv.value)}")
    IO.puts("Hex: #{Base.encode16(parsed_tlv.value)}")
    IO.puts("Hz value: #{parsed_hz}")
    IO.puts("MHz value: #{parsed_hz / 1_000_000}")

    # Check difference
    IO.puts("\n=== COMPARISON ===")
    IO.puts("Original Hz: #{original_hz}")
    IO.puts("Parsed Hz: #{parsed_hz}")
    IO.puts("Difference: #{abs(original_hz - parsed_hz)}")
    IO.puts("Match: #{original_binary == parsed_tlv.value}")
  end
end
