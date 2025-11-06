defmodule DebugJsonGenerationTest do
  use ExUnit.Case

  test "check JSON generation preserves string formatted_value" do
    # Create a TLV with frequency and enriched formatted_value
    # 305,419,896 Hz
    frequency_binary = <<0x12, 0x34, 0x56, 0x78>>

    # Simulate an enriched TLV (like what TlvEnricher produces)
    enriched_tlv = %{
      # Some type
      type: 1,
      length: 4,
      value: frequency_binary,
      value_type: :frequency,
      # STRING with unit
      formatted_value: "305.42 MHz"
    }

    IO.puts("\n=== ENRICHED TLV ===")
    IO.inspect(enriched_tlv, label: "Enriched TLV")

    # Generate JSON
    {:ok, json_string} =
      Bindocsis.Generators.JsonGenerator.generate([enriched_tlv], pretty: false)

    IO.puts("\n=== GENERATED JSON ===")
    IO.puts(json_string)

    # Parse the JSON to see what got encoded
    {:ok, decoded} = Jason.decode(json_string)

    IO.puts("\n=== DECODED JSON ===")
    IO.inspect(decoded, label: "Decoded JSON")

    # Check the formatted_value field
    first_tlv = hd(decoded["tlvs"])
    formatted_value = first_tlv["formatted_value"]

    IO.puts("\n=== FORMATTED VALUE CHECK ===")
    IO.puts("formatted_value: #{inspect(formatted_value)}")
    IO.puts("Type: #{formatted_value |> is_binary() |> if(do: "String", else: "NOT String")}")

    IO.puts(
      "Contains 'MHz': #{if is_binary(formatted_value), do: String.contains?(formatted_value, "MHz"), else: "N/A"}"
    )

    # ASSERT: formatted_value should be the STRING "305.42 MHz", NOT a number
    assert is_binary(formatted_value),
           "formatted_value should be a string, got: #{inspect(formatted_value)}"

    assert String.contains?(formatted_value, "MHz"), "formatted_value should contain 'MHz' unit"
  end
end
