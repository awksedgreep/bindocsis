defmodule Bindocsis.ParentFormattedValueTest do
  use ExUnit.Case, async: true

  alias Bindocsis.Generators.{JsonGenerator, YamlGenerator}

  @moduledoc "Round-trip defects from issue #7."

  # TLV 24 Upstream Service Flow: sub-TLV 1 (ref) + sub-TLV 6 (QoS set type)
  @compound <<24, 7, 1, 2, 0, 1, 6, 1, 7>>

  test "enriched parents with subtlvs carry no formatted_value" do
    {:ok, [parent]} = Bindocsis.parse(@compound, format: :binary, enhanced: true)
    assert length(parent.subtlvs) == 2
    refute Map.has_key?(parent, :formatted_value)
  end

  test "JSON and YAML emit subtlvs, not a formatted_value, for parents" do
    {:ok, tlvs} = Bindocsis.parse(@compound, format: :binary, enhanced: true)

    {:ok, json} = JsonGenerator.generate(tlvs)
    %{"tlvs" => [j]} = JSON.decode!(json)
    assert length(j["subtlvs"]) == 2
    refute Map.has_key?(j, "formatted_value")

    {:ok, yaml} = YamlGenerator.generate(tlvs)
    refute yaml =~ "Compound TLV with"
    assert yaml =~ "subtlvs:"

    # And both parse back to the same bytes
    assert {:ok, bin} = Bindocsis.HumanConfig.from_json(json)
    assert bin == @compound <> <<0xFF>> or bin == @compound
    assert {:ok, bin2} = Bindocsis.HumanConfig.from_yaml(yaml)
    assert bin2 == bin
  end

  test "unenriched compounds whose sub-TLVs use a 128-255 byte length keep their subtlvs" do
    # sub-TLV 4 with a 200-byte value: length byte 0xC8, one byte (not two)
    sub_value = :binary.copy(<<0x41>>, 200)
    value = <<1, 2, 0, 1, 4, 200>> <> sub_value
    tlv = %{type: 24, length: byte_size(value), value: value}

    {:ok, json} = JsonGenerator.generate([tlv])
    %{"tlvs" => [j]} = JSON.decode!(json)
    assert [%{"type" => 1}, %{"type" => 4, "length" => 200}] = j["subtlvs"]

    {:ok, yaml} = YamlGenerator.generate([tlv])
    assert yaml =~ "subtlvs:"
    assert yaml =~ "length: 200"
  end

  test "hex-looking :string values are never rewritten by the JSON hex heuristic" do
    for text <- ["beef", "cafe", "1234"] do
      tlv = %{
        type: 99,
        length: byte_size(text),
        value: text,
        value_type: :string,
        formatted_value: text
      }

      {:ok, json} = JsonGenerator.generate([tlv])
      %{"tlvs" => [j]} = JSON.decode!(json)
      assert j["value_type"] == "string"
      assert j["formatted_value"] == text

      {:ok, bin} = Bindocsis.HumanConfig.from_json(json)
      assert {:ok, [%{value: ^text}]} = Bindocsis.parse(bin, format: :binary, enhanced: false)
    end
  end
end
