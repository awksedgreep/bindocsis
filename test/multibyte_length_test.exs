defmodule Bindocsis.MultibyLengthTest do
  use ExUnit.Case
  doctest Bindocsis

  describe "single-byte length encoding (0-127)" do
    test "parses single-byte lengths correctly" do
      content = String.duplicate("x", 100)
      binary = <<5, 100>> <> content <> <<255>>
      
      assert {:ok, [%{type: 5, length: 100, value: ^content}]} = 
        Bindocsis.parse(binary, format: :binary)
    end

    test "handles boundary at 127 bytes" do
      content = String.duplicate("x", 127)
      binary = <<5, 127>> <> content <> <<255>>
      
      assert {:ok, [%{type: 5, length: 127, value: ^content}]} = 
        Bindocsis.parse(binary, format: :binary)
    end

    test "round-trip encoding for single-byte lengths" do
      original_tlvs = [%{type: 5, length: 100, value: String.duplicate("x", 100)}]
      
      assert {:ok, binary} = Bindocsis.Generators.BinaryGenerator.generate(original_tlvs)
      assert {:ok, ^original_tlvs} = Bindocsis.parse(binary, format: :binary, enhanced: false)
    end
  end

  describe "0x81 encoding (128-255 bytes)" do
    test "parses 0x81 encoded lengths correctly" do
      content = String.duplicate("y", 200)
      binary = <<5, 0x81, 200>> <> content <> <<255>>
      
      assert {:ok, [%{type: 5, length: 200, value: ^content}]} = 
        Bindocsis.parse(binary, format: :binary)
    end

    test "handles boundary at 128 bytes" do
      content = String.duplicate("x", 128)
      binary = <<5, 0x81, 128>> <> content <> <<255>>
      
      assert {:ok, [%{type: 5, length: 128, value: ^content}]} = 
        Bindocsis.parse(binary, format: :binary)
    end

    test "handles boundary at 255 bytes" do
      content = String.duplicate("z", 255)
      binary = <<5, 0x81, 255>> <> content <> <<255>>
      
      assert {:ok, [%{type: 5, length: 255, value: ^content}]} = 
        Bindocsis.parse(binary, format: :binary)
    end

    test "round-trip encoding for 0x81 lengths" do
      original_tlvs = [%{type: 5, length: 200, value: String.duplicate("x", 200)}]
      
      assert {:ok, binary} = Bindocsis.Generators.BinaryGenerator.generate(original_tlvs)
      assert {:ok, ^original_tlvs} = Bindocsis.parse(binary, format: :binary, enhanced: false)
    end

    test "fails with malformed 0x81 encoding (missing length byte)" do
      binary = <<5, 0x81>>  # Missing the length byte
      
      assert {:error, reason} = Bindocsis.parse(binary, format: :binary)
      assert reason =~ "Invalid"
    end

    test "fails with insufficient data for claimed length" do
      binary = <<5, 0x81, 200>> <> String.duplicate("x", 50) <> <<255>>  # Claims 200, has 50
      
      assert {:error, reason} = Bindocsis.parse(binary, format: :binary)
      assert reason =~ "insufficient data"
      assert reason =~ "200"
    end
  end

  describe "0x82 encoding (256-65535 bytes)" do
    test "parses 0x82 encoded lengths correctly" do
      content = String.duplicate("a", 300)
      binary = <<5, 0x82, 300::16>> <> content <> <<255>>
      
      assert {:ok, [%{type: 5, length: 300, value: ^content}]} = 
        Bindocsis.parse(binary, format: :binary)
    end

    test "handles boundary at 256 bytes" do
      content = String.duplicate("b", 256)
      binary = <<5, 0x82, 256::16>> <> content <> <<255>>
      
      assert {:ok, [%{type: 5, length: 256, value: ^content}]} = 
        Bindocsis.parse(binary, format: :binary)
    end

    test "handles large 0x82 lengths" do
      content = String.duplicate("c", 1000)
      binary = <<5, 0x82, 1000::16>> <> content <> <<255>>
      
      assert {:ok, [%{type: 5, length: 1000, value: ^content}]} = 
        Bindocsis.parse(binary, format: :binary)
    end

    test "round-trip encoding for 0x82 lengths" do
      original_tlvs = [%{type: 5, length: 300, value: String.duplicate("x", 300)}]
      
      assert {:ok, binary} = Bindocsis.Generators.BinaryGenerator.generate(original_tlvs)
      assert {:ok, ^original_tlvs} = Bindocsis.parse(binary, format: :binary, enhanced: false)
    end

    test "fails with malformed 0x82 encoding (incomplete length)" do
      binary = <<5, 0x82, 100>>  # Missing second byte for 0x82
      
      assert {:error, reason} = Bindocsis.parse(binary, format: :binary)
      assert reason =~ "insufficient data"
    end
  end

  describe "0x84 encoding (65536+ bytes)" do
    test "parses 0x84 length headers correctly" do
      # Don't actually create 70K of data, just test the header parsing
      large_length = 70_000
      small_content = String.duplicate("x", 100)  # Much smaller for testing
      binary = <<5, 0x84, large_length::32>> <> small_content
      
      # Should fail due to insufficient data, but error should mention the correct length
      assert {:error, reason} = Bindocsis.parse(binary, format: :binary)
      assert reason =~ "70000"
      assert reason =~ "insufficient data"
    end

    test "fails with malformed 0x84 encoding (incomplete length)" do
      binary = <<5, 0x84, 100, 200>>  # Missing two bytes for 0x84
      
      assert {:error, reason} = Bindocsis.parse(binary, format: :binary)
      assert reason =~ "insufficient data"
    end
  end

  describe "encoding format validation" do
    test "rejects using 0x81 for lengths > 255" do
      # This was the bug found in our comprehensive test
      # Trying to encode 272 bytes with 0x81 format (which only supports up to 255)
      content = String.duplicate("x", 272)
      # This creates malformed binary: 272 gets truncated to 16 when stored as single byte
      malformed_binary = <<5, 0x81, 272>> <> content <> <<255>>
      
      # The parser should not successfully parse this as a 272-byte value
      case Bindocsis.parse(malformed_binary, format: :binary) do
        {:ok, [%{length: length}]} ->
          # Should not parse as length 272 due to truncation
          refute length == 272
        {:error, _reason} ->
          # Acceptable - should fail to parse correctly
          assert true
      end
    end

    test "correctly uses 0x82 for lengths > 255" do
      content = String.duplicate("x", 272)
      correct_binary = <<5, 0x82, 272::16>> <> content <> <<255>>
      
      assert {:ok, [%{type: 5, length: 272, value: ^content}]} = 
        Bindocsis.parse(correct_binary, format: :binary)
    end

    test "rejects invalid length markers" do
      invalid_binaries = [
        <<5, 0x83, 100, 200>>,  # 0x83 is not valid
        <<5, 0x85, 100>>,       # 0x85 is not valid  
        <<5, 0x90, 100>>        # 0x90 is not valid
      ]
      
      for invalid_binary <- invalid_binaries do
        assert {:error, _reason} = Bindocsis.parse(invalid_binary, format: :binary)
      end
    end
  end

  describe "Unicode content with multi-byte lengths" do
    test "handles Unicode content with correct length encoding" do
      unicode_content = "Hello 世界! 🌍 Testing 测试 "
      repeated_content = String.duplicate(unicode_content, 8)
      byte_length = byte_size(repeated_content)
      
      # Use correct encoding for the byte length
      encoding_binary = cond do
        byte_length <= 127 -> <<5, byte_length>>
        byte_length <= 255 -> <<5, 0x81, byte_length>>
        byte_length <= 65535 -> <<5, 0x82, byte_length::16>>
        true -> <<5, 0x84, byte_length::32>>
      end
      
      complete_binary = encoding_binary <> repeated_content <> <<255>>
      
      assert {:ok, [%{type: 5, length: ^byte_length, value: ^repeated_content}]} = 
        Bindocsis.parse(complete_binary, format: :binary)
    end

    test "round-trip Unicode with multi-byte lengths" do
      unicode_content = "Café 世界 🎉 " |> String.duplicate(20)  # Force multi-byte length
      byte_length = byte_size(unicode_content)
      original_tlvs = [%{type: 5, length: byte_length, value: unicode_content}]
      
      assert {:ok, binary} = Bindocsis.Generators.BinaryGenerator.generate(original_tlvs)
      assert {:ok, ^original_tlvs} = Bindocsis.parse(binary, format: :binary, enhanced: false)
    end
  end

  describe "mixed length encodings" do
    test "handles multiple TLVs with different length encodings" do
      tlv1_content = String.duplicate("a", 50)    # Single-byte
      tlv2_content = String.duplicate("b", 200)   # 0x81
      tlv3_content = String.duplicate("c", 300)   # 0x82
      
      binary = <<1, 50>> <> tlv1_content <>
               <<2, 0x81, 200>> <> tlv2_content <>
               <<3, 0x82, 300::16>> <> tlv3_content <>
               <<255>>
      
      assert {:ok, [
        %{type: 1, length: 50, value: ^tlv1_content},
        %{type: 2, length: 200, value: ^tlv2_content},
        %{type: 3, length: 300, value: ^tlv3_content}
      ]} = Bindocsis.parse(binary, format: :binary)
    end

    test "handles alternating length encodings correctly" do
      contents = [
        {1, String.duplicate("1", 100)},    # Single
        {2, String.duplicate("2", 150)},    # 0x81  
        {3, String.duplicate("3", 75)},     # Single
        {4, String.duplicate("4", 400)}     # 0x82
      ]
      
      binary_parts = for {type, content} <- contents do
        length = byte_size(content)
        encoding = cond do
          length <= 127 -> <<type, length>>
          length <= 255 -> <<type, 0x81, length>>
          length <= 65535 -> <<type, 0x82, length::16>>
          true -> <<type, 0x84, length::32>>
        end
        encoding <> content
      end
      
      complete_binary = Enum.join(binary_parts, "") <> <<255>>
      
      assert {:ok, parsed_tlvs} = Bindocsis.parse(complete_binary, format: :binary)
      assert length(parsed_tlvs) == 4
      
      expected_lengths = [100, 150, 75, 400]
      actual_lengths = Enum.map(parsed_tlvs, & &1.length)
      assert actual_lengths == expected_lengths
    end
  end

  describe "boundary condition edge cases" do
    test "127 vs 128 byte boundary" do
      content_127 = String.duplicate("x", 127)
      content_128 = String.duplicate("y", 128)
      
      binary = <<1, 127>> <> content_127 <>           # Single-byte encoding
               <<2, 0x81, 128>> <> content_128 <>     # Must use 0x81 for 128
               <<255>>
      
      assert {:ok, [
        %{type: 1, length: 127, value: ^content_127},
        %{type: 2, length: 128, value: ^content_128}
      ]} = Bindocsis.parse(binary, format: :binary)
    end

    test "255 vs 256 byte boundary" do
      content_255 = String.duplicate("a", 255)
      content_256 = String.duplicate("b", 256)
      
      binary = <<1, 0x81, 255>> <> content_255 <>     # 0x81 encoding
               <<2, 0x82, 256::16>> <> content_256 <> # Must use 0x82 for 256
               <<255>>
      
      assert {:ok, [
        %{type: 1, length: 255, value: ^content_255},
        %{type: 2, length: 256, value: ^content_256}
      ]} = Bindocsis.parse(binary, format: :binary)
    end
  end

  describe "error recovery and malformed data" do
    test "detects truncated files during multi-byte length parsing" do
      binary = <<5, 0x82>>  # File ends after length marker
      
      assert {:error, reason} = Bindocsis.parse(binary, format: :binary)
      assert reason =~ "Invalid"
    end

    test "detects unreasonably large length claims" do
      huge_length = 2_000_000_000  # 2GB
      binary = <<5, 0x84, huge_length::32>> <> String.duplicate("x", 100)
      
      assert {:error, reason} = Bindocsis.parse(binary, format: :binary)
      assert reason =~ "insufficient data"
      assert reason =~ "2000000000"
    end

    test "handles partial corruption gracefully" do
      valid_tlv = <<1, 10>> <> String.duplicate("x", 10)
      corrupted_tlv = <<2, 0x81, 200>> <> String.duplicate("y", 50)  # Claims 200, has 50
      
      binary = valid_tlv <> corrupted_tlv
      
      assert {:error, reason} = Bindocsis.parse(binary, format: :binary)
      assert reason =~ "insufficient data"
    end
  end
end