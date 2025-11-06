defmodule ExtendedLengthEncodingTest do
  use ExUnit.Case, async: true
  require Logger

  @moduledoc """
  Comprehensive tests for Blocker #6: Extended TLV Length Encoding.
  
  Tests verify that:
  - Single-byte lengths (0-127) work correctly
  - Single-byte lengths (128-255) are NOT treated as extended length indicators
  - Extended length indicators (0x81, 0x82, 0x84) work correctly
  - Boundary values are handled properly
  - Both parsing and generation handle all length encodings
  """

  describe "Single-Byte Lengths (0-127)" do
    test "parses TLV with length 0" do
      binary = <<5, 0>>
      assert {:ok, tlvs} = Bindocsis.parse(binary, format: :binary)
      assert [%{type: 5, length: 0, value: <<>>}] = tlvs
    end

    test "parses TLV with length 1" do
      binary = <<5, 1, 42>>
      assert {:ok, tlvs} = Bindocsis.parse(binary, format: :binary)
      assert [%{type: 5, length: 1, value: <<42>>}] = tlvs
    end

    test "parses TLV with length 127 (max single-byte)" do
      value = :binary.copy(<<7>>, 127)
      binary = <<10, 127>> <> value
      assert {:ok, tlvs} = Bindocsis.parse(binary, format: :binary)
      assert [%{type: 10, length: 127, value: ^value}] = tlvs
    end

    test "round-trip for length 127" do
      value = :binary.copy(<<8>>, 127)
      tlvs = [%{type: 20, length: 127, value: value}]
      
      assert {:ok, binary} = Bindocsis.generate(tlvs, format: :binary, terminate: false)
      assert {:ok, parsed_tlvs} = Bindocsis.parse(binary, format: :binary)
      assert [%{type: 20, length: 127, value: ^value}] = parsed_tlvs
    end
  end

  describe "Single-Byte Lengths (128-255) - NOT Extended" do
    test "parses TLV with length 128 (0x80) as single-byte length" do
      value = :binary.copy(<<9>>, 128)
      # 0x80 should be interpreted as length 128, NOT as extended length indicator
      binary = <<15, 0x80>> <> value
      assert {:ok, tlvs} = Bindocsis.parse(binary, format: :binary)
      assert [%{type: 15, length: 128, value: ^value}] = tlvs
    end

    test "parses TLV with length 200 (0xC8)" do
      value = :binary.copy(<<10>>, 200)
      binary = <<25, 0xC8>> <> value
      assert {:ok, tlvs} = Bindocsis.parse(binary, format: :binary)
      assert [%{type: 25, length: 200, value: ^value}] = tlvs
    end

    test "parses TLV with length 254 (0xFE) - the original bug case" do
      # This is the specific case mentioned in public_release.md
      value = :binary.copy(<<11>>, 254)
      binary = <<5, 0xFE>> <> value
      assert {:ok, tlvs} = Bindocsis.parse(binary, format: :binary)
      assert [%{type: 5, length: 254, value: ^value}] = tlvs
    end

    test "parses TLV with length 255 (0xFF)" do
      value = :binary.copy(<<12>>, 255)
      # Note: 0xFF is the terminator, so we need to test without terminator
      binary = <<30, 0xFF>> <> value
      assert {:ok, tlvs} = Bindocsis.parse(binary, format: :binary)
      # Should parse as TLV, not as terminator when followed by data
      assert [%{type: 30, length: 255, value: ^value}] = tlvs
    end

    test "parses TLV with length 0x83 (131)" do
      # 0x83 should NOT be treated as 3-byte extended length indicator
      value = :binary.copy(<<13>>, 131)
      binary = <<35, 0x83>> <> value
      assert {:ok, tlvs} = Bindocsis.parse(binary, format: :binary)
      assert [%{type: 35, length: 131, value: ^value}] = tlvs
    end

    test "parses TLV with length 0x85 (133)" do
      # 0x85 should NOT be treated as 5-byte extended length indicator
      value = :binary.copy(<<14>>, 133)
      binary = <<40, 0x85>> <> value
      assert {:ok, tlvs} = Bindocsis.parse(binary, format: :binary)
      assert [%{type: 40, length: 133, value: ^value}] = tlvs
    end

    test "round-trip for length 128" do
      value = :binary.copy(<<15>>, 128)
      tlvs = [%{type: 45, length: 128, value: value}]
      
      # Generate should use 0x81 extended encoding for length 128
      assert {:ok, binary} = Bindocsis.generate(tlvs, format: :binary, terminate: false)
      assert <<45, 0x81, 128, _rest::binary>> = binary
      
      # Parse back
      assert {:ok, parsed_tlvs} = Bindocsis.parse(binary, format: :binary)
      assert [%{type: 45, length: 128, value: ^value}] = parsed_tlvs
    end

    test "round-trip for length 254" do
      value = :binary.copy(<<16>>, 254)
      tlvs = [%{type: 50, length: 254, value: value}]
      
      # Generate should use 0x81 extended encoding for length 254
      assert {:ok, binary} = Bindocsis.generate(tlvs, format: :binary, terminate: false)
      assert <<50, 0x81, 254, _rest::binary>> = binary
      
      # Parse back
      assert {:ok, parsed_tlvs} = Bindocsis.parse(binary, format: :binary)
      assert [%{type: 50, length: 254, value: ^value}] = parsed_tlvs
    end
  end

  describe "Extended Length Encoding (0x81, 0x82, 0x84)" do
    test "parses TLV with 0x81 extended length (1-byte)" do
      # 0x81 followed by 1-byte length
      value = :binary.copy(<<17>>, 200)
      binary = <<55, 0x81, 200>> <> value
      assert {:ok, tlvs} = Bindocsis.parse(binary, format: :binary)
      assert [%{type: 55, length: 200, value: ^value}] = tlvs
    end

    test "parses TLV with 0x82 extended length (2-byte)" do
      # 0x82 followed by 2-byte length
      value = :binary.copy(<<18>>, 1000)
      binary = <<60, 0x82, 1000::16>> <> value
      assert {:ok, tlvs} = Bindocsis.parse(binary, format: :binary)
      assert [%{type: 60, length: 1000, value: ^value}] = tlvs
    end

    test "parses TLV with 0x82 for length 256" do
      # Boundary: 256 requires 0x82 encoding
      value = :binary.copy(<<19>>, 256)
      binary = <<65, 0x82, 256::16>> <> value
      assert {:ok, tlvs} = Bindocsis.parse(binary, format: :binary)
      assert [%{type: 65, length: 256, value: ^value}] = tlvs
    end

    test "parses TLV with 0x82 for length 65535 (max 2-byte)" do
      # Maximum 2-byte length
      value = :binary.copy(<<20>>, 65535)
      binary = <<70, 0x82, 65535::16>> <> value
      assert {:ok, tlvs} = Bindocsis.parse(binary, format: :binary)
      assert [%{type: 70, length: 65535, value: ^value}] = tlvs
    end

    @tag :skip
    test "parses TLV with 0x84 extended length (4-byte)" do
      # Skip: Very large test
      # 0x84 followed by 4-byte length
      value = :binary.copy(<<21>>, 70000)
      binary = <<75, 0x84, 70000::32>> <> value
      assert {:ok, tlvs} = Bindocsis.parse(binary, format: :binary)
      assert [%{type: 75, length: 70000, value: ^value}] = tlvs
    end

    test "round-trip with 0x82 encoding" do
      value = :binary.copy(<<22>>, 5000)
      tlvs = [%{type: 80, length: 5000, value: value}]
      
      assert {:ok, binary} = Bindocsis.generate(tlvs, format: :binary, terminate: false)
      assert <<80, 0x82, 5000::16, _rest::binary>> = binary
      
      assert {:ok, parsed_tlvs} = Bindocsis.parse(binary, format: :binary)
      assert [%{type: 80, length: 5000, value: ^value}] = parsed_tlvs
    end
  end

  describe "Boundary Values" do
    test "length 127 uses single-byte encoding" do
      value = :binary.copy(<<23>>, 127)
      tlvs = [%{type: 85, length: 127, value: value}]
      
      assert {:ok, binary} = Bindocsis.generate(tlvs, format: :binary, terminate: false)
      assert <<85, 127, _rest::binary>> = binary
    end

    test "length 128 uses 0x81 extended encoding" do
      value = :binary.copy(<<24>>, 128)
      tlvs = [%{type: 90, length: 128, value: value}]
      
      assert {:ok, binary} = Bindocsis.generate(tlvs, format: :binary, terminate: false)
      assert <<90, 0x81, 128, _rest::binary>> = binary
    end

    test "length 255 uses 0x81 extended encoding" do
      value = :binary.copy(<<25>>, 255)
      tlvs = [%{type: 95, length: 255, value: value}]
      
      assert {:ok, binary} = Bindocsis.generate(tlvs, format: :binary, terminate: false)
      assert <<95, 0x81, 255, _rest::binary>> = binary
    end

    test "length 256 uses 0x82 extended encoding" do
      value = :binary.copy(<<26>>, 256)
      tlvs = [%{type: 100, length: 256, value: value}]
      
      assert {:ok, binary} = Bindocsis.generate(tlvs, format: :binary, terminate: false)
      assert <<100, 0x82, 256::16, _rest::binary>> = binary
    end

    test "length 65535 uses 0x82 extended encoding" do
      value = :binary.copy(<<27>>, 65535)
      tlvs = [%{type: 105, length: 65535, value: value}]
      
      assert {:ok, binary} = Bindocsis.generate(tlvs, format: :binary, terminate: false)
      assert <<105, 0x82, 65535::16, _rest::binary>> = binary
    end

    test "length 65536 uses 0x84 extended encoding" do
      value = :binary.copy(<<28>>, 65536)
      tlvs = [%{type: 110, length: 65536, value: value}]
      
      assert {:ok, binary} = Bindocsis.generate(tlvs, format: :binary, terminate: false)
      assert <<110, 0x84, 65536::32, _rest::binary>> = binary
    end
  end

  describe "Multiple TLVs with Mixed Lengths" do
    test "parses multiple TLVs with various length encodings" do
      # TLV 1: length 50 (single-byte)
      tlv1 = <<10, 50>> <> :binary.copy(<<1>>, 50)
      
      # TLV 2: length 150 (0x81 extended)
      tlv2 = <<20, 0x81, 150>> <> :binary.copy(<<2>>, 150)
      
      # TLV 3: length 5000 (0x82 extended)
      tlv3 = <<30, 0x82, 5000::16>> <> :binary.copy(<<3>>, 5000)
      
      binary = tlv1 <> tlv2 <> tlv3
      
      assert {:ok, tlvs} = Bindocsis.parse(binary, format: :binary)
      assert length(tlvs) == 3
      assert [%{type: 10, length: 50}, %{type: 20, length: 150}, %{type: 30, length: 5000}] = tlvs
    end

    test "round-trip with mixed length encodings" do
      tlvs = [
        %{type: 1, length: 10, value: :binary.copy(<<1>>, 10)},
        %{type: 2, length: 200, value: :binary.copy(<<2>>, 200)},
        %{type: 3, length: 2000, value: :binary.copy(<<3>>, 2000)}
      ]
      
      assert {:ok, binary} = Bindocsis.generate(tlvs, format: :binary, terminate: false)
      assert {:ok, parsed_tlvs} = Bindocsis.parse(binary, format: :binary)
      
      assert length(parsed_tlvs) == 3
      assert [%{type: 1, length: 10}, %{type: 2, length: 200}, %{type: 3, length: 2000}] = parsed_tlvs
    end
  end

  describe "Error Cases" do
    test "rejects 0x81 without following length byte" do
      binary = <<10, 0x81>>
      assert {:error, _reason} = Bindocsis.parse(binary, format: :binary)
    end

    test "rejects 0x82 without following 2 length bytes" do
      binary = <<10, 0x82, 100>>
      assert {:error, _reason} = Bindocsis.parse(binary, format: :binary)
    end

    test "rejects 0x84 without following 4 length bytes" do
      binary = <<10, 0x84, 100, 200>>
      assert {:error, _reason} = Bindocsis.parse(binary, format: :binary)
    end

    test "rejects TLV claiming more data than available" do
      # Claims length 100 but only has 50 bytes
      binary = <<10, 100>> <> :binary.copy(<<1>>, 50)
      assert {:error, reason} = Bindocsis.parse(binary, format: :binary)
      assert reason =~ "insufficient data"
    end
  end

  describe "Real-World Scenarios" do
    test "parses config with TLV 43 length 254 (from public_release.md)" do
      # This is the specific case mentioned as an edge case
      value = :binary.copy(<<99>>, 254)
      binary = <<43, 0xFE>> <> value
      
      assert {:ok, tlvs} = Bindocsis.parse(binary, format: :binary)
      assert [%{type: 43, length: 254, value: ^value}] = tlvs
    end

    test "handles compound TLV with length > 127" do
      # Service flow TLV with multiple sub-TLVs totaling > 127 bytes
      sub_tlv1 = <<1, 50>> <> :binary.copy(<<1>>, 50)
      sub_tlv2 = <<2, 100>> <> :binary.copy(<<2>>, 100)
      subtlv_data = sub_tlv1 <> sub_tlv2
      
      # Type 24 (Upstream Service Flow) with length > 127
      length = byte_size(subtlv_data)
      binary = <<24, 0x81, length>> <> subtlv_data
      
      assert {:ok, tlvs} = Bindocsis.parse(binary, format: :binary)
      assert [%{type: 24, length: ^length}] = tlvs
    end
  end
end
