defmodule Bindocsis.Unit.JsonGeneratorHexCorrectionTest do
  use ExUnit.Case, async: true

  alias Bindocsis.Generators.JsonGenerator

  describe "correct_hex_string_value_type function application" do
    test "is NOT applied when TLV is enriched with atomic value_type" do
      # Create a TLV that has been enriched with a known atomic value_type
      enriched_tlv = %{
        type: 3,
        length: 4,
        value: <<0, 3, 13, 64>>,
        name: "Maximum Upstream Rate",
        value_type: :uint32,
        formatted_value: "200000"
      }

      # Generate JSON
      {:ok, json_string} = JsonGenerator.generate([enriched_tlv])

      # Parse the JSON to verify
      {:ok, json_data} = JSON.decode(json_string)
      tlv_json = hd(json_data["tlvs"])

      # The value_type should remain uint32 (NOT changed to hex_string)
      assert tlv_json["value_type"] == "uint32"
      # The formatted_value should remain as the decimal string (NOT converted to hex)
      assert tlv_json["formatted_value"] == "200000"
    end

    test "is NOT applied when TLV has name and atomic value_type :uint16" do
      enriched_tlv = %{
        type: 5,
        length: 2,
        value: <<1, 244>>,
        name: "Some Config",
        value_type: :uint16,
        formatted_value: "500"
      }

      {:ok, json_string} = JsonGenerator.generate([enriched_tlv])
      {:ok, json_data} = JSON.decode(json_string)
      tlv_json = hd(json_data["tlvs"])

      assert tlv_json["value_type"] == "uint16"
      assert tlv_json["formatted_value"] == "500"
    end

    test "is NOT applied when TLV has name and atomic value_type :frequency" do
      enriched_tlv = %{
        type: 1,
        length: 4,
        value: <<35, 57, 241, 192>>,
        name: "Downstream Frequency",
        value_type: :frequency,
        formatted_value: "591000000"
      }

      {:ok, json_string} = JsonGenerator.generate([enriched_tlv])
      {:ok, json_data} = JSON.decode(json_string)
      tlv_json = hd(json_data["tlvs"])

      assert tlv_json["value_type"] == "frequency"
      assert tlv_json["formatted_value"] == "591000000"
    end

    test "is NOT applied when TLV has name and atomic value_type :string" do
      enriched_tlv = %{
        type: 10,
        length: 5,
        value: "hello",
        name: "Some String Field",
        value_type: :string,
        formatted_value: "hello"
      }

      {:ok, json_string} = JsonGenerator.generate([enriched_tlv])
      {:ok, json_data} = JSON.decode(json_string)
      tlv_json = hd(json_data["tlvs"])

      assert tlv_json["value_type"] == "string"
      assert tlv_json["formatted_value"] == "hello"
    end

    test "is NOT applied when TLV has name and atomic value_type :ipv4" do
      enriched_tlv = %{
        type: 20,
        length: 4,
        value: <<192, 168, 1, 1>>,
        name: "IP Address",
        value_type: :ipv4,
        formatted_value: "192.168.1.1"
      }

      {:ok, json_string} = JsonGenerator.generate([enriched_tlv])
      {:ok, json_data} = JSON.decode(json_string)
      tlv_json = hd(json_data["tlvs"])

      assert tlv_json["value_type"] == "ipv4"
      assert tlv_json["formatted_value"] == "192.168.1.1"
    end

    test "IS applied when TLV is missing name (not enriched)" do
      # Create a TLV without name (unenriched)
      unenriched_tlv = %{
        type: 99,
        length: 4,
        value: <<0x20, 0x00, 0x00, 0x00>>,
        value_type: :unknown,
        formatted_value: "20000000"
      }

      {:ok, json_string} = JsonGenerator.generate([unenriched_tlv])
      {:ok, json_data} = JSON.decode(json_string)
      tlv_json = hd(json_data["tlvs"])

      # Because it looks like hex and wasn't enriched, it should be corrected
      assert tlv_json["value_type"] == "hex_string"
      # The formatted_value should be converted to hex string format
      assert String.contains?(tlv_json["formatted_value"], "20")
    end

    test "IS applied when TLV has name but non-atomic value_type" do
      # TLV with name but value_type is :unknown (not atomic)
      tlv = %{
        type: 99,
        length: 3,
        value: <<0xAB, 0xCD, 0xEF>>,
        name: "Some Unknown Field",
        value_type: :unknown,
        formatted_value: "ABCDEF"
      }

      {:ok, json_string} = JsonGenerator.generate([tlv])
      {:ok, json_data} = JSON.decode(json_string)
      tlv_json = hd(json_data["tlvs"])

      # Should be corrected to hex_string
      assert tlv_json["value_type"] == "hex_string"
    end

    test "IS applied when TLV is missing both name and atomic value_type" do
      unenriched_tlv = %{
        type: 100,
        length: 2,
        value: <<0xFF, 0xAA>>,
        formatted_value: "FFAA"
      }

      {:ok, json_string} = JsonGenerator.generate([unenriched_tlv])
      {:ok, json_data} = JSON.decode(json_string)
      tlv_json = hd(json_data["tlvs"])

      # Should be corrected to hex_string
      assert tlv_json["value_type"] == "hex_string"
    end
  end

  describe "enriched TLV value_type and formatted_value preservation" do
    test "enriched uint32 TLV retains value_type and formatted_value after JSON generation" do
      enriched_tlv = %{
        type: 3,
        length: 4,
        value: <<0, 3, 13, 64>>,
        name: "Network Access Control",
        description: "Enable/disable network access",
        value_type: :uint32,
        formatted_value: "200000"
      }

      {:ok, json_string} = JsonGenerator.generate([enriched_tlv])
      {:ok, json_data} = JSON.decode(json_string)
      tlv_json = hd(json_data["tlvs"])

      # Verify all critical fields are preserved correctly
      assert tlv_json["type"] == 3
      assert tlv_json["length"] == 4
      assert tlv_json["name"] == "Network Access Control"
      assert tlv_json["value_type"] == "uint32"
      assert tlv_json["formatted_value"] == "200000"
    end

    test "enriched uint16 TLV retains value_type and formatted_value" do
      enriched_tlv = %{
        type: 8,
        length: 2,
        value: <<1, 0>>,
        name: "Some Setting",
        value_type: :uint16,
        formatted_value: "256"
      }

      {:ok, json_string} = JsonGenerator.generate([enriched_tlv])
      {:ok, json_data} = JSON.decode(json_string)
      tlv_json = hd(json_data["tlvs"])

      assert tlv_json["value_type"] == "uint16"
      assert tlv_json["formatted_value"] == "256"
    end

    test "enriched string TLV retains value_type and formatted_value" do
      enriched_tlv = %{
        type: 15,
        length: 9,
        value: "test_name",
        name: "Configuration Name",
        value_type: :string,
        formatted_value: "test_name"
      }

      {:ok, json_string} = JsonGenerator.generate([enriched_tlv])
      {:ok, json_data} = JSON.decode(json_string)
      tlv_json = hd(json_data["tlvs"])

      assert tlv_json["value_type"] == "string"
      assert tlv_json["formatted_value"] == "test_name"
    end

    test "enriched frequency TLV retains value_type and formatted_value" do
      enriched_tlv = %{
        type: 1,
        length: 4,
        value: <<35, 57, 241, 192>>,
        name: "Downstream Frequency",
        value_type: :frequency,
        formatted_value: "591000000"
      }

      {:ok, json_string} = JsonGenerator.generate([enriched_tlv])
      {:ok, json_data} = JSON.decode(json_string)
      tlv_json = hd(json_data["tlvs"])

      assert tlv_json["value_type"] == "frequency"
      assert tlv_json["formatted_value"] == "591000000"
    end

    test "enriched boolean TLV retains value_type and formatted_value" do
      enriched_tlv = %{
        type: 3,
        length: 1,
        value: <<1>>,
        name: "Network Access Control",
        value_type: :boolean,
        formatted_value: "Enabled"
      }

      {:ok, json_string} = JsonGenerator.generate([enriched_tlv])
      {:ok, json_data} = JSON.decode(json_string)
      tlv_json = hd(json_data["tlvs"])

      assert tlv_json["value_type"] == "boolean"
      assert tlv_json["formatted_value"] == "Enabled"
    end
  end

  describe "unenriched TLV hex_string correction" do
    test "unenriched TLV with hex-like value gets value_type updated to hex_string" do
      unenriched_tlv = %{
        type: 99,
        length: 4,
        value: <<0x12, 0x34, 0x56, 0x78>>,
        formatted_value: "12345678"
      }

      {:ok, json_string} = JsonGenerator.generate([unenriched_tlv])
      {:ok, json_data} = JSON.decode(json_string)
      tlv_json = hd(json_data["tlvs"])

      # Should be corrected to hex_string
      assert tlv_json["value_type"] == "hex_string"
      # Should be formatted as spaced hex string
      assert tlv_json["formatted_value"] == "12 34 56 78"
    end

    test "unenriched TLV formatted_value is properly formatted as hex string" do
      unenriched_tlv = %{
        type: 100,
        length: 3,
        value: <<0xAB, 0xCD, 0xEF>>,
        formatted_value: "ABCDEF"
      }

      {:ok, json_string} = JsonGenerator.generate([unenriched_tlv])
      {:ok, json_data} = JSON.decode(json_string)
      tlv_json = hd(json_data["tlvs"])

      assert tlv_json["value_type"] == "hex_string"
      assert tlv_json["formatted_value"] == "AB CD EF"
    end

    test "unenriched compound TLV that failed subtlv parsing gets hex_string correction" do
      # Simulate a compound TLV that failed to parse as subtlvs
      # and was given a hex string formatted_value by the enricher
      failed_compound_tlv = %{
        type: 43,
        length: 4,
        value: <<0xFF, 0xAA, 0xBB, 0xCC>>,
        value_type: :hex_string,
        formatted_value: "FF AA BB CC"
      }

      {:ok, json_string} = JsonGenerator.generate([failed_compound_tlv])
      {:ok, json_data} = JSON.decode(json_string)
      tlv_json = hd(json_data["tlvs"])

      # Should retain hex_string value_type
      assert tlv_json["value_type"] == "hex_string"
      assert tlv_json["formatted_value"] == "FF AA BB CC"
    end
  end

  describe "integration with complex TLV configurations" do
    test "complex configuration with mixed enriched and unenriched TLVs" do
      tlvs = [
        # Enriched atomic TLV
        %{
          type: 3,
          length: 4,
          value: <<0, 3, 13, 64>>,
          name: "Network Access Control",
          value_type: :uint32,
          formatted_value: "200000"
        },
        # Unenriched TLV
        %{
          type: 99,
          length: 2,
          value: <<0xAB, 0xCD>>,
          formatted_value: "ABCD"
        },
        # Enriched string TLV
        %{
          type: 15,
          length: 4,
          value: "test",
          name: "Config Name",
          value_type: :string,
          formatted_value: "test"
        }
      ]

      {:ok, json_string} = JsonGenerator.generate(tlvs)
      {:ok, json_data} = JSON.decode(json_string)
      json_tlvs = json_data["tlvs"]

      # First TLV: enriched, should keep uint32
      assert Enum.at(json_tlvs, 0)["value_type"] == "uint32"
      assert Enum.at(json_tlvs, 0)["formatted_value"] == "200000"

      # Second TLV: unenriched, should be corrected to hex_string
      assert Enum.at(json_tlvs, 1)["value_type"] == "hex_string"
      assert Enum.at(json_tlvs, 1)["formatted_value"] == "AB CD"

      # Third TLV: enriched, should keep string
      assert Enum.at(json_tlvs, 2)["value_type"] == "string"
      assert Enum.at(json_tlvs, 2)["formatted_value"] == "test"
    end

    test "compound TLV with enriched subtlvs preserves all value types correctly" do
      compound_tlv = %{
        type: 24,
        length: 0,
        value: <<>>,
        name: "Downstream Service Flow",
        value_type: :compound,
        subtlvs: [
          %{
            type: 1,
            length: 4,
            value: <<0, 0, 1, 0>>,
            name: "Service Flow Reference",
            value_type: :uint32,
            formatted_value: "256"
          },
          %{
            type: 3,
            length: 4,
            value: <<0, 3, 13, 64>>,
            name: "Maximum Sustained Rate",
            value_type: :uint32,
            formatted_value: "200000"
          }
        ]
      }

      {:ok, json_string} = JsonGenerator.generate([compound_tlv])
      {:ok, json_data} = JSON.decode(json_string)
      tlv_json = hd(json_data["tlvs"])

      # Parent compound TLV
      assert tlv_json["type"] == 24
      assert tlv_json["name"] == "Downstream Service Flow"

      # Sub-TLVs should all preserve their enriched types
      subtlvs = tlv_json["subtlvs"]
      assert length(subtlvs) == 2

      assert Enum.at(subtlvs, 0)["value_type"] == "uint32"
      assert Enum.at(subtlvs, 0)["formatted_value"] == "256"

      assert Enum.at(subtlvs, 1)["value_type"] == "uint32"
      assert Enum.at(subtlvs, 1)["formatted_value"] == "200000"
    end
  end
end
