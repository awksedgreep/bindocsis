defmodule VerifyEnrichmentTheoryTest do
  use ExUnit.Case

  test "unenriched TLV produces NUMBER in JSON" do
    # TLV without enrichment (no :formatted_value field)
    unenriched_tlv = %{type: 1, length: 4, value: <<0x12, 0x34, 0x56, 0x78>>}

    {:ok, json_string} =
      Bindocsis.Generators.JsonGenerator.generate([unenriched_tlv], pretty: false)

    {:ok, decoded} = Jason.decode(json_string)

    first_tlv = hd(decoded["tlvs"])
    formatted_value = first_tlv["formatted_value"]

    IO.puts("\n=== UNENRICHED TLV ==")
    IO.puts("formatted_value: #{inspect(formatted_value)}")
    IO.puts("Type: #{if is_binary(formatted_value), do: "String", else: "Number"}")

    assert is_number(formatted_value), "Expected NUMBER from unenriched TLV"
  end

  test "enriched TLV produces STRING in JSON" do
    # TLV WITH enrichment (:formatted_value field present)
    unenriched_tlv = %{type: 1, length: 4, value: <<0x12, 0x34, 0x56, 0x78>>}

    # Enrich it
    enriched_tlv = Bindocsis.TlvEnricher.enrich_tlv(unenriched_tlv)

    {:ok, json_string} =
      Bindocsis.Generators.JsonGenerator.generate([enriched_tlv], pretty: false)

    {:ok, decoded} = Jason.decode(json_string)

    first_tlv = hd(decoded["tlvs"])
    formatted_value = first_tlv["formatted_value"]

    IO.puts("\n=== ENRICHED TLV ===")
    IO.puts("formatted_value: #{inspect(formatted_value)}")
    IO.puts("Type: #{if is_binary(formatted_value), do: "String", else: "Number"}")

    assert is_binary(formatted_value),
           "Expected STRING from enriched TLV, got: #{inspect(formatted_value)}"

    assert String.contains?(formatted_value, "MHz"), "Expected 'MHz' unit in formatted_value"
  end
end
