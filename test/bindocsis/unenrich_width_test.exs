defmodule Bindocsis.UnenrichWidthTest do
  use ExUnit.Case, async: true

  alias Bindocsis.TlvEnricher

  @moduledoc "unenrich honours the edited value length (issue #8)."

  test "an unchanged formatted_value keeps the original bytes verbatim" do
    tlv = %{
      type: 43,
      length: 2,
      value: <<0x00, 0x0A>>,
      value_type: :hex_string,
      formatted_value: "000A"
    }

    assert %{value: <<0x00, 0x0A>>, length: 2} = TlvEnricher.unenrich_tlv(tlv)
  end

  test "a shortened hex edit is not zero-padded back to the old width" do
    tlv = %{
      type: 43,
      length: 2,
      value: <<0x00, 0x0A>>,
      value_type: :hex_string,
      formatted_value: "0A"
    }

    assert %{value: <<0x0A>>, length: 1} = TlvEnricher.unenrich_tlv(tlv)
  end

  test "a shortened string edit keeps the new length" do
    tlv = %{
      type: 9,
      length: 6,
      value: "abcdef",
      value_type: :string,
      formatted_value: "abc"
    }

    assert %{value: "abc", length: 3} = TlvEnricher.unenrich_tlv(tlv)
  end

  test "enrich -> unenrich -> generate reproduces the input bytes" do
    bin = <<3, 1, 1, 24, 7, 1, 2, 0, 1, 6, 1, 7, 18, 1, 5, 0xFF>>
    {:ok, enriched} = Bindocsis.parse(bin, format: :binary, enhanced: true)
    raw = TlvEnricher.unenrich_tlvs(enriched)
    {:ok, out} = Bindocsis.generate(raw, format: :binary)
    assert out == bin
  end
end
