defmodule ConfigFormatTest do
  use ExUnit.Case

  describe "config parsing" do
    test "parses simple boolean TLVs" do
      config = """
      WebAccessControl enabled
      NetworkAccessControl disabled
      """

      assert {:ok, tlvs} = Bindocsis.parse(config, format: :config, enhanced: false)
      assert length(tlvs) == 2

      assert %{type: 3, length: 1, value: <<1>>} in tlvs
      assert %{type: 0, length: 1, value: <<0>>} in tlvs
    end

    test "parses frequency values" do
      config = "DownstreamFrequency 591000000"

      assert {:ok, [tlv]} = Bindocsis.parse(config, format: :config, enhanced: false)
      assert %{type: 1, length: 4, value: <<35, 57, 241, 192>>} = tlv
    end

    test "parses power values" do
      config = "MaxUpstreamTransmitPower 58"

      assert {:ok, [tlv]} = Bindocsis.parse(config, format: :config, enhanced: false)
      # 58 * 4 = 232
      assert %{type: 2, length: 1, value: <<232>>} = tlv
    end

    test "parses IP addresses" do
      config = "IPAddress 192.168.1.1"

      assert {:ok, [tlv]} = Bindocsis.parse(config, format: :config, enhanced: false)
      assert %{type: 4, length: 4, value: <<192, 168, 1, 1>>} = tlv
    end

    test "parses integer values" do
      config = "UpstreamChannelID 5"

      assert {:ok, [tlv]} = Bindocsis.parse(config, format: :config, enhanced: false)
      assert %{type: 8, length: 1, value: <<5>>} = tlv
    end

    test "handles comments and empty lines" do
      config = """
      # This is a comment
      WebAccessControl enabled

      # Another comment
      DownstreamFrequency 591000000
      """

      assert {:ok, tlvs} = Bindocsis.parse(config, format: :config, enhanced: false)
      assert length(tlvs) == 2
    end

    test "case insensitive TLV names" do
      config = """
      webaccesscontrol enabled
      DOWNSTREAMFREQUENCY 591000000
      MaxUpstreamTransmitPower 58
      """

      assert {:ok, tlvs} = Bindocsis.parse(config, format: :config, enhanced: false)
      assert length(tlvs) == 3

      types = Enum.map(tlvs, & &1.type) |> Enum.sort()
      assert types == [1, 2, 3]
    end

    test "handles boolean variations" do
      config = """
      WebAccessControl true
      NetworkAccessControl false
      UpstreamChannelID 1
      MaxUpstreamTransmitPower 0
      """

      assert {:ok, tlvs} = Bindocsis.parse(config, format: :config, enhanced: false)

      web_access = Enum.find(tlvs, &(&1.type == 3))
      assert %{value: <<1>>} = web_access

      network_access = Enum.find(tlvs, &(&1.type == 0))
      assert %{value: <<0>>} = network_access
    end

    test "handles hex values" do
      config = "TFTPServer AA:BB:CC:DD:EE:FF"

      assert {:ok, [tlv]} = Bindocsis.parse(config, format: :config, enhanced: false)
      assert %{type: 6, length: 6, value: <<0xAA, 0xBB, 0xCC, 0xDD, 0xEE, 0xFF>>} = tlv
    end

    test "handles numeric variations" do
      config = """
      DownstreamFrequency 591000000
      UpstreamChannelID 0x05
      MaxUpstreamTransmitPower 58.5
      """

      assert {:ok, tlvs} = Bindocsis.parse(config, format: :config, enhanced: false)
      assert length(tlvs) == 3

      channel_id = Enum.find(tlvs, &(&1.type == 8))
      assert %{value: <<5>>} = channel_id

      power = Enum.find(tlvs, &(&1.type == 2))
      # 58.5 * 4 = 234 (truncated)
      assert %{value: <<234>>} = power
    end

    test "error handling for unknown TLV names" do
      config = "UnknownTLVName value"

      assert {:error, error_msg} = Bindocsis.parse(config, format: :config, enhanced: false)
      assert String.contains?(error_msg, "Unknown TLV name")
    end

    test "error handling for missing values" do
      config = "WebAccessControl"

      assert {:error, error_msg} = Bindocsis.parse(config, format: :config, enhanced: false)
      assert String.contains?(error_msg, "Missing value")
    end

    test "error handling for invalid IP addresses" do
      config = "IPAddress 999.999.999.999"

      assert {:error, error_msg} = Bindocsis.parse(config, format: :config, enhanced: false)
      assert String.contains?(error_msg, "Invalid")
    end

    test "error handling for invalid boolean values" do
      config = "WebAccessControl maybe"

      assert {:error, error_msg} = Bindocsis.parse(config, format: :config, enhanced: false)
      assert String.contains?(error_msg, "Expected boolean")
    end
  end

  describe "config generation" do
    test "generates simple TLVs correctly" do
      tlvs = [
        %{type: 3, length: 1, value: <<1>>},
        %{type: 1, length: 4, value: <<35, 68, 153, 0>>}
      ]

      assert {:ok, config} = Bindocsis.generate(tlvs, format: :config)

      assert String.contains?(config, "WebAccessControl enabled")
      assert String.contains?(config, "DownstreamFrequency")
      assert String.contains?(config, "# DOCSIS Configuration File")
    end

    test "generates boolean values correctly" do
      tlvs = [
        %{type: 3, length: 1, value: <<1>>},
        %{type: 0, length: 1, value: <<0>>}
      ]

      assert {:ok, config} = Bindocsis.generate(tlvs, format: :config)

      assert String.contains?(config, "WebAccessControl enabled")
      assert String.contains?(config, "NetworkAccessControl disabled")
    end

    test "generates IP addresses correctly" do
      tlvs = [%{type: 4, length: 4, value: <<192, 168, 1, 1>>}]

      assert {:ok, config} = Bindocsis.generate(tlvs, format: :config)

      assert String.contains?(config, "IPAddress 192.168.1.1")
    end

    test "generates MAC addresses correctly" do
      tlvs = [%{type: 7, length: 6, value: <<0xAA, 0xBB, 0xCC, 0xDD, 0xEE, 0xFF>>}]

      assert {:ok, config} = Bindocsis.generate(tlvs, format: :config)

      assert String.contains?(config, "SoftwareUpgradeServer AA:BB:CC:DD:EE:FF")
    end

    test "generates power values correctly" do
      # 58 dBmV * 4
      tlvs = [%{type: 2, length: 1, value: <<232>>}]

      assert {:ok, config} = Bindocsis.generate(tlvs, format: :config)

      assert String.contains?(config, "MaxUpstreamTransmitPower 58")
    end

    test "generates frequency values correctly" do
      # 591 MHz
      tlvs = [%{type: 1, length: 4, value: <<35, 68, 153, 0>>}]

      assert {:ok, config} = Bindocsis.generate(tlvs, format: :config)

      assert String.contains?(config, "DownstreamFrequency")
      assert String.contains?(config, "591")
    end

    test "generates without header when disabled" do
      tlvs = [%{type: 3, length: 1, value: <<1>>}]

      assert {:ok, config} = Bindocsis.generate(tlvs, format: :config, include_header: false)

      refute String.contains?(config, "# DOCSIS Configuration File")
      assert String.contains?(config, "WebAccessControl enabled")
    end

    test "generates without comments when disabled" do
      tlvs = [%{type: 3, length: 1, value: <<1>>}]

      assert {:ok, config} = Bindocsis.generate(tlvs, format: :config, include_comments: false)

      refute String.contains?(config, "# Web-based management")
      assert String.contains?(config, "WebAccessControl enabled")
    end

    test "generates compact format" do
      tlvs = [
        %{type: 3, length: 1, value: <<1>>},
        %{type: 1, length: 4, value: <<35, 68, 153, 0>>}
      ]

      assert {:ok, config} = Bindocsis.generate(tlvs, format: :config, format_style: :compact)

      # Compact format should have less whitespace
      lines = String.split(config, "\n")
      # Should not have as many empty lines as standard format
      empty_lines = Enum.count(lines, &(&1 == ""))
      assert empty_lines < 3
    end

    test "handles unknown TLV types gracefully" do
      tlvs = [%{type: 999, length: 2, value: <<0xAA, 0xBB>>}]

      assert {:ok, config} = Bindocsis.generate(tlvs, format: :config)

      assert String.contains?(config, "# Unknown TLV Type 999")
      assert String.contains?(config, "TLV999")
      assert String.contains?(config, "AA BB")
    end

    test "handles binary data as hex" do
      tlvs = [%{type: 17, length: 3, value: <<0x01, 0x02, 0x03>>}]

      assert {:ok, config} = Bindocsis.generate(tlvs, format: :config)

      assert String.contains?(config, "01 02 03")
    end
  end

  describe "round-trip conversion" do
    test "simple TLVs maintain fidelity" do
      original_config = """
      WebAccessControl enabled
      NetworkAccessControl disabled
      DownstreamFrequency 591000000
      MaxUpstreamTransmitPower 58
      """

      {:ok, tlvs} = Bindocsis.parse(original_config, format: :config)
      {:ok, binary} = Bindocsis.generate(tlvs, format: :binary)

      # Parse the binary back to TLVs and compare structure directly
      {:ok, binary_tlvs} = Bindocsis.parse(binary, format: :binary)
      {:ok, original_tlvs} = Bindocsis.parse(original_config, format: :config)

      # Should have same number of TLVs
      assert length(original_tlvs) == length(binary_tlvs)

      # Should have same types and values
      Enum.zip(original_tlvs, binary_tlvs)
      |> Enum.each(fn {orig, binary} ->
        assert orig.type == binary.type
        assert orig.length == binary.length
        assert orig.value == binary.value
      end)
    end

    test "config -> JSON -> config maintains readability" do
      config = "WebAccessControl enabled\nDownstreamFrequency 591000000"

      {:ok, json} = Bindocsis.convert(config, from: :config, to: :json)
      {:ok, back_to_config} = Bindocsis.convert(json, from: :json, to: :config)

      assert String.contains?(back_to_config, "WebAccessControl")
      assert String.contains?(back_to_config, "DownstreamFrequency")
    end

    test "config -> YAML -> config maintains structure" do
      config = "WebAccessControl enabled\nUpstreamChannelID 5"

      {:ok, yaml} = Bindocsis.convert(config, from: :config, to: :yaml)
      {:ok, back_to_config} = Bindocsis.convert(yaml, from: :yaml, to: :config)

      {:ok, original_tlvs} = Bindocsis.parse(config, format: :config, enhanced: false)
      {:ok, roundtrip_tlvs} = Bindocsis.parse(back_to_config, format: :config)

      # Compare essential structure
      assert length(original_tlvs) == length(roundtrip_tlvs)
    end
  end

  describe "file operations" do
    test "parses config file correctly" do
      test_file = Path.join(System.tmp_dir!(), "test_config.conf")

      config_content = """
      # Test DOCSIS Config
      WebAccessControl enabled
      DownstreamFrequency 591000000
      """

      File.write!(test_file, config_content)

      try do
        assert {:ok, tlvs} = Bindocsis.parse_file(test_file)
        assert length(tlvs) == 2

        types = Enum.map(tlvs, & &1.type) |> Enum.sort()
        assert types == [1, 3]
      after
        File.rm(test_file)
      end
    end

    test "writes config file correctly" do
      test_file = Path.join(System.tmp_dir!(), "test_output.conf")

      tlvs = [
        %{type: 3, length: 1, value: <<1>>},
        %{type: 1, length: 4, value: <<35, 68, 153, 0>>}
      ]

      try do
        assert :ok = Bindocsis.write_file(tlvs, test_file, format: :config)

        {:ok, content} = File.read(test_file)
        assert String.contains?(content, "WebAccessControl enabled")
        assert String.contains?(content, "DownstreamFrequency")
        assert String.contains?(content, "# DOCSIS Configuration File")
      after
        File.rm(test_file)
      end
    end

    test "auto-detects config format from .conf extension" do
      test_file = Path.join(System.tmp_dir!(), "test_auto.conf")
      config_content = "WebAccessControl enabled"

      File.write!(test_file, config_content)

      try do
        # Should auto-detect
        assert {:ok, tlvs} = Bindocsis.parse_file(test_file)
        assert [%{type: 3, length: 1, value: <<1>>}] = tlvs
      after
        File.rm(test_file)
      end
    end
  end

  describe "validation and error handling" do
    test "validates config structure" do
      valid_config = "WebAccessControl enabled"
      assert :ok = Bindocsis.Parsers.ConfigParser.validate_structure(valid_config)

      empty_config = "# Just comments\n\n"
      assert {:error, _} = Bindocsis.Parsers.ConfigParser.validate_structure(empty_config)
    end

    test "provides helpful error messages" do
      config = "WebAccessControl invalid_value"

      assert {:error, error_msg} = Bindocsis.parse(config, format: :config, enhanced: false)
      assert String.contains?(error_msg, "Line 1")
      assert String.contains?(error_msg, "Expected boolean")
    end

    test "handles malformed lines gracefully" do
      config = "InvalidLine without proper format"

      assert {:error, error_msg} = Bindocsis.parse(config, format: :config, enhanced: false)
      assert String.contains?(error_msg, "Unknown TLV name")
    end

    test "gets TLV type by name" do
      assert {:ok, 3} = Bindocsis.Parsers.ConfigParser.get_tlv_type("WebAccessControl")
      assert {:ok, 3} = Bindocsis.Parsers.ConfigParser.get_tlv_type("webaccesscontrol")
      assert {:error, :not_found} = Bindocsis.Parsers.ConfigParser.get_tlv_type("Unknown")
    end

    test "lists supported TLV names" do
      names = Bindocsis.Parsers.ConfigParser.supported_tlv_names()
      assert is_list(names)
      assert "webaccesscontrol" in names
      assert "downstreamfrequency" in names
    end
  end

  describe "real-world scenarios" do
    test "handles typical cable modem config" do
      config = """
      # Basic Cable Modem Configuration
      NetworkAccessControl enabled
      WebAccessControl disabled
      DownstreamFrequency 591000000
      MaxUpstreamTransmitPower 58
      UpstreamChannelID 3
      IPAddress 192.168.100.1
      SubnetMask 255.255.255.0
      """

      assert {:ok, tlvs} = Bindocsis.parse(config, format: :config, enhanced: false)
      assert length(tlvs) == 7

      # Verify we can convert to other formats
      assert {:ok, _json} = Bindocsis.generate(tlvs, format: :json)
      assert {:ok, _yaml} = Bindocsis.generate(tlvs, format: :yaml)
      assert {:ok, _binary} = Bindocsis.generate(tlvs, format: :binary)
    end

    test "handles mixed case and spacing variations" do
      config = """
      WebAccessControl    enabled
      DownstreamFrequency 591000000
      MaxUpstreamTransmitPower 58
      """

      # Should parse despite formatting variations
      assert {:ok, tlvs} = Bindocsis.parse(config, format: :config, enhanced: false)
      assert length(tlvs) == 3
    end

    test "preserves data integrity across format conversions" do
      original_binary = <<3, 1, 1, 1, 4, 35, 57, 241, 192, 2, 1, 232>>

      # Binary -> Config (simplified without comments) -> Binary
      {:ok, tlvs} = Bindocsis.parse(original_binary, format: :binary)

      {:ok, config} =
        Bindocsis.generate(tlvs, format: :config, include_comments: false, include_header: false)

      {:ok, back_to_binary} = Bindocsis.convert(config, from: :config, to: :binary)

      # Parse both binaries to compare TLV structure
      {:ok, original_tlvs} = Bindocsis.parse(original_binary, format: :binary)
      {:ok, roundtrip_tlvs} = Bindocsis.parse(back_to_binary, format: :binary)

      # Should have same TLV structure (though binary may have terminator)
      assert length(original_tlvs) == length(roundtrip_tlvs)

      Enum.zip(original_tlvs, roundtrip_tlvs)
      |> Enum.each(fn {orig, roundtrip} ->
        assert orig.type == roundtrip.type
        assert orig.length == roundtrip.length
        assert orig.value == roundtrip.value
      end)
    end
  end
end
