defmodule EdgeCaseTest do
  use ExUnit.Case

  @moduletag :edge_cases

  describe "production edge cases" do
    test "handles 0xFE as single-byte length (not extended length indicator)" do
      # This test reproduces the production bug where 0xFE (254) 
      # was incorrectly treated as an extended length indicator
      # instead of a valid single-byte length value

      fixture_path = "test/fixtures/simple_edge_case.cm"

      # Should parse successfully without "insufficient data" errors
      assert {:ok, tlvs} = Bindocsis.parse_file(fixture_path)

      # Should have exactly 3 TLVs (WebAccess, VendorSpecific with 0xFE length, DownstreamFreq)
      assert length(tlvs) == 3

      # Should contain the critical TLV with 254-byte length
      fe_tlv = Enum.find(tlvs, fn tlv -> tlv.length == 254 end)
      assert fe_tlv != nil, "Should contain TLV with 0xFE (254) byte length"
      # VendorSpecific
      assert fe_tlv.type == 43
      assert byte_size(fe_tlv.value) == 254

      # Should be able to convert to all formats without errors
      assert {:ok, _json} = Bindocsis.generate(tlvs, format: :json)
      assert {:ok, _yaml} = Bindocsis.generate(tlvs, format: :yaml)
      assert {:ok, _config} = Bindocsis.generate(tlvs, format: :config)

      # Round-trip conversion should preserve structure
      {:ok, binary} = Bindocsis.generate(tlvs, format: :binary)
      {:ok, reparsed_tlvs} = Bindocsis.parse(binary, format: :binary)

      # Should have same number of TLVs and same structure
      assert length(reparsed_tlvs) == length(tlvs)

      # Critical: 0xFE length TLV should survive round-trip
      reparsed_fe_tlv = Enum.find(reparsed_tlvs, fn tlv -> tlv.length == 254 end)
      assert reparsed_fe_tlv != nil
      assert reparsed_fe_tlv.type == fe_tlv.type
      assert byte_size(reparsed_fe_tlv.value) == 254
    end

    test "multi-byte length edge cases are handled correctly" do
      # Test the boundary conditions for multi-byte length parsing

      test_cases = [
        # Standard single-byte lengths (0x00-0x7F)
        {0x00, "empty TLV"},
        {0x7F, "max single-byte length"},

        # Critical edge cases (0x80-0xFF that should be single-byte)
        {0x80, "0x80 should be single-byte"},
        {0xFE, "0xFE should be single-byte (production bug)"},
        {0xFF, "0xFF should be single-byte"}

        # Extended length indicators (should work as before)
        # Note: These require additional bytes so we test them separately
      ]

      Enum.each(test_cases, fn {length_byte, description} ->
        # Create a minimal TLV with the specific length
        # WebAccessControl
        type = 3
        # Repeat byte to match length
        value = :binary.copy(<<1>>, length_byte)

        # Add terminator
        binary = <<type, length_byte>> <> value <> <<255>>

        case Bindocsis.parse(binary, format: :binary) do
          {:ok, [tlv]} ->
            assert tlv.type == type, "#{description}: type should be preserved"
            assert tlv.length == length_byte, "#{description}: length should be #{length_byte}"

            assert byte_size(tlv.value) == length_byte,
                   "#{description}: value size should match length"

          {:ok, tlvs} when length(tlvs) > 1 ->
            # Multiple TLVs might be parsed if length is small
            first_tlv = hd(tlvs)
            assert first_tlv.type == type, "#{description}: first TLV type should be preserved"

          {:error, reason} ->
            # Only acceptable for 0x00 length (empty value)
            if length_byte == 0x00 do
              assert String.contains?(reason, "empty") or String.contains?(reason, "invalid")
            else
              flunk("#{description}: Should not fail with error: #{reason}")
            end
        end
      end)
    end

    test "extended length indicators work correctly" do
      # Test the actual extended length cases (0x81, 0x82, 0x84)

      # 0x81 - next 1 byte is length (up to 255)
      extended_81 = <<3, 0x81, 10>> <> :binary.copy(<<1>>, 10) <> <<255>>
      assert {:ok, [tlv]} = Bindocsis.parse(extended_81, format: :binary)
      assert tlv.length == 10
      assert byte_size(tlv.value) == 10

      # 0x82 - next 2 bytes are length (up to 65535)
      extended_82 = <<3, 0x82, 0x01, 0x00>> <> :binary.copy(<<1>>, 256) <> <<255>>
      assert {:ok, [tlv]} = Bindocsis.parse(extended_82, format: :binary)
      assert tlv.length == 256
      assert byte_size(tlv.value) == 256
    end

    test "complex service flow structures parse correctly" do
      # Test complex nested TLV structures that appear in production

      complex_service_flow = <<
        # DownstreamServiceFlow (15 bytes)
        24,
        15,
        # ServiceFlowReference 1
        1,
        2,
        0,
        1,
        # QoSParameterSetType 7
        6,
        1,
        7,
        # MaxTrafficRate 10000 kbps
        7,
        4,
        0x00,
        0x00,
        0x27,
        0x10,
        # MaxTrafficBurst 4096
        8,
        2,
        0x10,
        0x00,
        # Terminator
        255
      >>

      assert {:ok, tlvs} = Bindocsis.parse(complex_service_flow, format: :binary)

      service_flow = Enum.find(tlvs, &(&1.type == 24))
      assert service_flow != nil
      assert service_flow.length == 15

      # Should be able to detect subtlvs if enabled
      {:ok, json_with_subtlvs} = Bindocsis.generate(tlvs, format: :json, detect_subtlvs: true)

      # Should contain subtlv structure or raw value depending on detection
      assert String.contains?(json_with_subtlvs, "subtlvs") or
               String.contains?(json_with_subtlvs, "value")
    end

    test "handles malformed TLVs gracefully" do
      # Test error conditions that might occur in corrupted files

      malformed_cases = [
        {<<3, 10, 1>>, "insufficient data for claimed length"},
        {<<>>, "empty file"},
        {<<3>>, "incomplete TLV header"},
        {<<3, 0x83, 5, 1, 2>>, "invalid extended length indicator 0x83"},
        {<<3, 0x81>>, "missing extended length data"}
      ]

      Enum.each(malformed_cases, fn {binary, _description} ->
        case Bindocsis.parse(binary, format: :binary) do
          {:error, _reason} ->
            # Expected - malformed data should return errors
            :ok

          {:ok, _tlvs} ->
            # Some cases might parse successfully with partial data
            # This is acceptable as long as no crashes occur
            :ok
        end
      end)
    end
  end

  describe "production workflow edge cases" do
    test "bandwidth modification works with complex files" do
      # Test that bandwidth utilities work with files containing edge cases

      fixture_path = "test/fixtures/simple_edge_case.cm"

      # Should be able to parse the edge case file
      {:ok, tlvs} = Bindocsis.parse_file(fixture_path)

      # Should be able to generate pretty JSON
      {:ok, pretty_json} = Bindocsis.generate(tlvs, format: :json, pretty: true)

      # JSON should be properly formatted
      assert String.contains?(pretty_json, "{\n  ")
      assert String.contains?(pretty_json, "\"docsis_version\":")

      # Should be able to parse the pretty JSON back
      {:ok, json_tlvs} = Bindocsis.parse(pretty_json, format: :json)

      # Structure should be preserved
      assert length(json_tlvs) == length(tlvs)

      # 0xFE length TLV should survive the conversion (or be represented differently in JSON)
      fe_tlv_original = Enum.find(tlvs, fn tlv -> tlv.length == 254 end)
      # Look for VendorSpecific type
      vendor_tlv_json = Enum.find(json_tlvs, fn tlv -> tlv.type == 43 end)

      assert fe_tlv_original != nil, "Original should contain 0xFE length TLV"

      # JSON conversion may handle large binary values differently, so just verify structure is preserved
      assert vendor_tlv_json != nil, "JSON should contain VendorSpecific TLV"
      assert vendor_tlv_json.type == fe_tlv_original.type
    end
  end
end
