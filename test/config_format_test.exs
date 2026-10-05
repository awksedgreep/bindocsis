defmodule ConfigFormatTest do
  use ExUnit.Case

  @moduledoc """
  Text config format (issue #6): names derive from the spec tables, values
  from ValueParser/ValueFormatter, compounds nest, and generate |> parse is
  byte-exact.
  """

  alias Bindocsis.{ConfigNames, TlvLength}
  alias Bindocsis.Parsers.ConfigParser

  defp parse!(text), do: Bindocsis.parse(text, format: :config, enhanced: false) |> elem(1)

  describe "names come from the specification" do
    test "top-level identifiers are DocsisSpecs names with punctuation removed" do
      assert {:ok, 3} = ConfigParser.get_tlv_type("NetworkAccessControl")
      assert {:ok, 1} = ConfigParser.get_tlv_type("DownstreamFrequency")
      assert {:ok, 2} = ConfigParser.get_tlv_type("UpstreamChannelID")
      assert {:ok, 6} = ConfigParser.get_tlv_type("CMMessageIntegrityCheck")
      assert {:ok, 7} = ConfigParser.get_tlv_type("CMTSMIC")
      assert {:ok, 8} = ConfigParser.get_tlv_type("VendorID")
      assert {:ok, 9} = ConfigParser.get_tlv_type("SWUpgradeFilename")
      assert {:ok, 12} = ConfigParser.get_tlv_type("ModemIPAddress")
      assert {:ok, 18} = ConfigParser.get_tlv_type("MaxNumberOfCPEs")
      assert {:ok, 24} = ConfigParser.get_tlv_type("UpstreamServiceFlow")
      assert {:ok, 39} = ConfigParser.get_tlv_type("Enable20Mode")
    end

    test "lookups are case-insensitive and ignore separators" do
      assert {:ok, 3} = ConfigParser.get_tlv_type("networkaccesscontrol")
      assert {:ok, 3} = ConfigParser.get_tlv_type("NETWORK_ACCESS_CONTROL")
      assert {:ok, 3} = ConfigParser.get_tlv_type("network-access-control")
    end

    test "the fabricated names from the old hand-written table are gone" do
      for bogus <- ~w(WebAccessControl TFTPServer IPAddress SubnetMask cmic NTPServer) do
        assert {:error, :not_found} = ConfigParser.get_tlv_type(bogus), bogus
      end
    end

    test "every DOCSIS and MTA spec name maps back to its own type" do
      for {type, id} <- ConfigNames.docsis_names() do
        assert {:ok, ^type} = ConfigNames.type_for(id, [], :docsis), id
      end

      for {type, id} <- ConfigNames.mta_names() do
        assert {:ok, ^type} = ConfigNames.type_for(id, [], :mta), id
      end
    end

    test "identifiers shared by the DOCSIS and MTA tables never disagree on the type" do
      docsis = Map.new(ConfigNames.docsis_names(), fn {t, id} -> {String.downcase(id), t} end)

      for {type, id} <- ConfigNames.mta_names(), Map.has_key?(docsis, String.downcase(id)) do
        assert docsis[String.downcase(id)] == type, id
      end
    end

    test "sub-TLV names come from SubTlvSpecs for the parent path" do
      assert ConfigNames.name(1, [24], :docsis) == "ServiceFlowReference"
      assert ConfigNames.name(6, [24], :docsis) == "QoSParameterSetType"
      assert {:ok, 6} = ConfigNames.type_for("QoSParameterSetType", [24], :docsis)
      assert ConfigNames.name(200, [24], :docsis) == "TLV200"
    end

    test "generic TLV<n> works everywhere" do
      assert {:ok, 254} = ConfigParser.get_tlv_type("TLV254")
      assert {:ok, 7} = ConfigNames.type_for("tlv7", [24], :docsis)
      assert {:error, :not_found} = ConfigParser.get_tlv_type("TLV256")
    end

    test "supported_tlv_names/0 lists the spec identifiers" do
      names = ConfigParser.supported_tlv_names()
      assert "NetworkAccessControl" in names
      assert "MTAConfigurationFile" in names
      refute "WebAccessControl" in names
    end
  end

  describe "parsing leaves" do
    test "booleans, integers, frequencies, addresses, strings" do
      config = """
      # comment
      // also a comment
      NetworkAccessControl enabled
      UpstreamChannelID 5
      DownstreamFrequency 591000000
      ModemIPAddress 192.168.1.1
      CPEEthernetMACAddress AA:BB:CC:DD:EE:FF
      SWUpgradeFilename "modem 1.2.bin"
      MaxNumberOfCPEs 16
      """

      assert parse!(config) == [
               %{type: 3, length: 1, value: <<1>>},
               %{type: 2, length: 1, value: <<5>>},
               %{type: 1, length: 4, value: <<35, 57, 241, 192>>},
               %{type: 12, length: 4, value: <<192, 168, 1, 1>>},
               %{type: 14, length: 6, value: <<0xAA, 0xBB, 0xCC, 0xDD, 0xEE, 0xFF>>},
               %{type: 9, length: 13, value: "modem 1.2.bin"},
               %{type: 18, length: 1, value: <<16>>}
             ]
    end

    test "the same human forms as JSON/YAML formatted_value are accepted" do
      assert [%{type: 1, value: <<35, 57, 241, 192>>}] = parse!("DownstreamFrequency 591 MHz")
      assert [%{type: 3, value: <<0>>}] = parse!("NetworkAccessControl off")
      assert [%{type: 3, value: <<1>>}] = parse!("NetworkAccessControl 1")
    end

    test "binary-typed TLVs take hex bytes in several spellings or a quoted string" do
      mic = :binary.copy(<<0xAB>>, 16)

      spaced =
        mic
        |> Base.encode16()
        |> String.graphemes()
        |> Enum.chunk_every(2)
        |> Enum.map_join(" ", &Enum.join/1)

      assert [%{type: 6, value: ^mic}] = parse!("CMMessageIntegrityCheck #{spaced}")
      assert [%{type: 6, value: ^mic}] = parse!("CMMessageIntegrityCheck 0x#{Base.encode16(mic)}")

      assert [%{type: 6, value: ^mic}] =
               parse!("CMMessageIntegrityCheck #{Base.encode16(mic, case: :lower)}")

      assert [%{type: 254, value: "raw"}] = parse!(~s(TLV254 "raw"))
      assert [%{type: 254, value: <<>>, length: 0}] = parse!(~s(TLV254 ""))
    end

    test "0x-prefixed hex is raw bytes for any value type" do
      assert [%{type: 1, value: <<1, 2, 3, 4>>}] = parse!("DownstreamFrequency 0x01020304")
    end

    test "quoted strings support escaped quotes and backslashes" do
      assert [%{type: 9, value: ~s(a"b\\c)}] = parse!(~S(SWUpgradeFilename "a\"b\\c"))
    end
  end

  describe "parsing compounds" do
    test "sub-TLV names resolve in the parent's context and nest" do
      config = """
      UpstreamServiceFlow {
          ServiceFlowReference 1
          QoSParameterSetType 7
          ServiceClassName "gold"
      }
      UpstreamPacketClassification {
          ClassifierReference 1
          IPv4PacketClassificationEncodings {
              TLV3 1.0.0.6
          }
      }
      """

      assert [
               %{type: 24, value: <<1, 2, 0, 1, 6, 1, 7, 4, 5, "gold", 0>>},
               %{type: 22, value: <<1, 1, 1, 9, 6, 3, 4, 1, 0, 0, 6>>}
             ] = parse!(config)
    end

    test "empty blocks and single-line blocks" do
      assert [%{type: 24, length: 0, value: <<>>}] = parse!("UpstreamServiceFlow { }")

      assert [%{type: 24, value: <<1, 2, 0, 9>>}] =
               parse!("UpstreamServiceFlow { ServiceFlowReference 9 }")
    end

    test "sub-TLV lengths use the shared codec (128-255 is one byte)" do
      # TLV 254 has no spec, so its children are untyped and take the
      # quoted string verbatim
      name = String.duplicate("x", 200)
      [%{type: 254, value: value}] = parse!(~s(TLV254 {\n TLV1 "#{name}"\n}))
      assert value == <<1>> <> TlvLength.encode(200) <> name
      assert {:ok, [%{type: 1, length: 200}]} = TlvLength.split(value)
    end
  end

  describe "errors fail the whole parse with a line number" do
    test "unknown names" do
      assert {:error, msg} = Bindocsis.parse("UnknownTLVName value", format: :config)
      assert msg =~ "Line 1"
      assert msg =~ "Unknown TLV name"
    end

    test "a bad line in the middle is not silently dropped" do
      config = "NetworkAccessControl enabled\nNoSuchThing 1\nUpstreamChannelID 5\n"
      assert {:error, msg} = Bindocsis.parse(config, format: :config)
      assert msg =~ "Line 2"
    end

    test "missing value, bad boolean, bad address, unclosed and stray braces" do
      assert {:error, msg} = Bindocsis.parse("NetworkAccessControl", format: :config)
      assert msg =~ "Missing value"

      assert {:error, msg} = Bindocsis.parse("NetworkAccessControl maybe", format: :config)
      assert msg =~ "Line 1" and msg =~ "Invalid value"

      assert {:error, msg} = Bindocsis.parse("ModemIPAddress 999.999.999.999", format: :config)
      assert msg =~ "Invalid"

      assert {:error, msg} =
               Bindocsis.parse("UpstreamServiceFlow {\nServiceFlowReference 1\n", format: :config)

      assert msg =~ "unclosed block"

      assert {:error, msg} = Bindocsis.parse("NetworkAccessControl on\n}\n", format: :config)
      assert msg =~ "Line 2" and msg =~ "unexpected '}'"
    end

    test "hex is required for binary types" do
      assert {:error, msg} = Bindocsis.parse("CMMessageIntegrityCheck not-hex", format: :config)
      assert msg =~ "hex"
    end
  end

  describe "generation" do
    test "emits spec names, human values, comments and header" do
      tlvs = [
        %{type: 3, length: 1, value: <<1>>},
        %{type: 1, length: 4, value: <<35, 57, 241, 192>>}
      ]

      {:ok, config} = Bindocsis.generate(tlvs, format: :config)
      assert config =~ "# DOCSIS Configuration File"
      assert config =~ "# Enable/disable network access"
      assert config =~ "NetworkAccessControl Enabled"
      assert config =~ "DownstreamFrequency 591 MHz"

      {:ok, bare} =
        Bindocsis.generate(tlvs, format: :config, include_header: false, include_comments: false)

      refute bare =~ "#"
      assert bare == "NetworkAccessControl Enabled\n\nDownstreamFrequency 591 MHz\n"

      {:ok, compact} =
        Bindocsis.generate(tlvs,
          format: :config,
          include_header: false,
          include_comments: false,
          format_style: :compact
        )

      assert compact == "NetworkAccessControl Enabled\nDownstreamFrequency 591 MHz\n"
    end

    test "compounds are nested blocks with spec sub-names" do
      tlvs = [%{type: 24, length: 7, value: <<1, 2, 0, 1, 6, 1, 7>>}]

      {:ok, config} =
        Bindocsis.generate(tlvs, format: :config, include_header: false, include_comments: false)

      assert config == """
             UpstreamServiceFlow {
                 ServiceFlowReference 1
                 QoSParameterSetType Provisioned+Admitted+Active
             }
             """
    end

    test "unknown types use TLV<n> and hex; binary types use spaced hex; empty values are quoted" do
      tlvs = [
        %{type: 254, length: 2, value: <<0xAA, 0xBB>>},
        %{type: 6, length: 3, value: <<1, 2, 3>>},
        %{type: 9, length: 0, value: <<>>}
      ]

      {:ok, config} =
        Bindocsis.generate(tlvs, format: :config, include_header: false, include_comments: false)

      assert config =~ "TLV254 AA BB"
      assert config =~ "CMMessageIntegrityCheck 01 02 03"
      assert config =~ ~s(SWUpgradeFilename "")
    end

    test "a compound whose bytes are not a sub-TLV sequence is written as hex" do
      tlvs = [%{type: 24, length: 3, value: <<9, 200, 1>>}]

      {:ok, config} =
        Bindocsis.generate(tlvs, format: :config, include_header: false, include_comments: false)

      assert config =~ "UpstreamServiceFlow 0x09C801"
      assert parse!(config) == tlvs
    end

    test "values the formatter cannot represent losslessly fall back to 0x hex" do
      # A 2-byte value in a uint8 field cannot be written as a number
      tlvs = [%{type: 18, length: 2, value: <<0, 5>>}]

      {:ok, config} =
        Bindocsis.generate(tlvs, format: :config, include_header: false, include_comments: false)

      assert config =~ "MaxNumberofCPEs 0x0005"
      assert parse!(config) == tlvs
    end
  end

  describe "round trips" do
    @cases [
      %{type: 3, length: 1, value: <<1>>},
      %{type: 1, length: 4, value: <<35, 57, 241, 193>>},
      %{type: 2, length: 1, value: <<200>>},
      %{type: 9, length: 9, value: "a\"b c.bin"},
      %{type: 12, length: 4, value: <<10, 0, 0, 1>>},
      %{type: 14, length: 6, value: <<1, 2, 3, 4, 5, 6>>},
      %{type: 6, length: 16, value: :binary.copy(<<0xAB>>, 16)},
      %{type: 11, length: 6, value: <<48, 4, 6, 2, 43, 6>>},
      %{type: 24, length: 11, value: <<1, 2, 0, 1, 6, 1, 7, 8, 2, 0, 7>>},
      %{type: 22, length: 9, value: <<1, 1, 1, 9, 4, 3, 1, 0, 6>>},
      %{type: 43, length: 5, value: <<8, 3, 0, 0x10, 0x95>>},
      %{type: 43, length: 3, value: <<0, 0, 0>>},
      %{type: 254, length: 3, value: <<1, 2, 3>>},
      %{type: 200, length: 0, value: <<>>},
      %{type: 18, length: 2, value: <<0, 5>>},
      %{type: 9, length: 2, value: <<0, 255>>}
    ]

    test "generate |> parse is byte-exact for every case, with and without comments" do
      for opts <- [[], [include_comments: false, include_header: false, format_style: :compact]] do
        {:ok, config} = Bindocsis.generate(@cases, [format: :config] ++ opts)
        assert parse!(config) == @cases
      end
    end

    test "binary -> config -> binary is byte-exact for the fixture corpus" do
      fixtures = Path.wildcard("test/fixtures/*.cm")
      assert fixtures != []

      for path <- fixtures do
        bytes = File.read!(path)

        case Bindocsis.parse(bytes, format: :binary, enhanced: false) do
          {:ok, tlvs} ->
            {:ok, config} = Bindocsis.generate(tlvs, format: :config)
            assert {:ok, back} = Bindocsis.parse(config, format: :config, enhanced: false), path
            assert back == tlvs, "config round-trip differs for #{path}"

          {:error, _} ->
            :skip
        end
      end
    end

    test "config -> JSON -> config and config -> YAML -> config keep the TLVs" do
      config = "NetworkAccessControl enabled\nUpstreamChannelID 5\nDownstreamFrequency 591 MHz\n"
      expected = parse!(config)

      {:ok, json} = Bindocsis.convert(config, from: :config, to: :json)
      {:ok, back} = Bindocsis.convert(json, from: :json, to: :config)
      assert parse!(back) == expected

      {:ok, yaml} = Bindocsis.convert(config, from: :config, to: :yaml)
      {:ok, back} = Bindocsis.convert(yaml, from: :yaml, to: :config)
      assert parse!(back) == expected
    end
  end

  describe "MTA files" do
    test "MTA names resolve and MTA-parsed TLVs generate MTA names" do
      assert {:ok, 64} = ConfigParser.get_tlv_type("MTAConfigurationFile")
      assert {:ok, 69} = ConfigParser.get_tlv_type("KerberosRealm")

      config = """
      NetworkAccessControl on
      MTAConfigurationFile {
          TLV1 "voice"
      }
      KerberosRealm "REALM.EXAMPLE"
      """

      parsed =
        Bindocsis.parse(config, format: :config, enhanced: false, file_type: :mta) |> elem(1)

      assert [
               %{type: 3, value: <<1>>},
               %{type: 64, value: <<1, 5, "voice">>},
               %{type: 69, value: "REALM.EXAMPLE"}
             ] = parsed

      {:ok, bin} = Bindocsis.generate(parsed, format: :mta, terminate: false)
      {:ok, mta_tlvs} = Bindocsis.parse(bin, format: :mta)
      {:ok, text} = Bindocsis.generate(mta_tlvs, format: :config, include_comments: false)
      assert text =~ "# PacketCable MTA Configuration File"
      assert text =~ "MTAConfigurationFile {"
      # MTA sub-TLVs have no spec table here: generic name, raw bytes
      assert text =~ "TLV1 76 6F 69 63 65"
      assert text =~ ~s(KerberosRealm "REALM.EXAMPLE")

      assert Bindocsis.parse(text, format: :config, enhanced: false, file_type: :mta) ==
               {:ok, parsed}
    end
  end

  describe "file operations" do
    test "parse_file auto-detects .conf and write_file round-trips" do
      dir = Path.join(System.tmp_dir!(), "bindocsis_config_format_test")
      File.mkdir_p!(dir)
      path = Path.join(dir, "t.conf")

      try do
        tlvs = [
          %{type: 3, length: 1, value: <<1>>},
          %{type: 1, length: 4, value: <<35, 68, 153, 0>>}
        ]

        assert :ok = Bindocsis.write_file(tlvs, path, format: :config)
        assert File.read!(path) =~ "NetworkAccessControl Enabled"
        assert {:ok, ^tlvs} = Bindocsis.parse_file(path, enhanced: false)
      after
        File.rm_rf!(dir)
      end
    end

    test "validate_structure" do
      assert :ok = ConfigParser.validate_structure("NetworkAccessControl enabled")
      assert {:error, _} = ConfigParser.validate_structure("# Just comments\n\n")
      assert {:ok, _} = ConfigParser.validate_structure([%{type: 3, length: 1, value: <<1>>}])
      assert {:error, _} = ConfigParser.validate_structure([%{type: 3, length: 2, value: <<1>>}])
    end
  end
end
