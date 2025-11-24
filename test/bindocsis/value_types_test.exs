defmodule Bindocsis.ValueTypesTest do
  use ExUnit.Case
  alias Bindocsis.ValueFormatter
  alias Bindocsis.ValueParser

  describe "OID value type" do
    test "formats OID correctly" do
      # 1.3.6.1.4.1
      oid_binary = <<43, 6, 1, 4, 1>>
      assert {:ok, "1.3.6.1.4.1"} = ValueFormatter.format_value(:oid, oid_binary)
    end

    test "parses OID string correctly" do
      assert {:ok, oid_binary} = ValueParser.parse_value(:oid, "1.3.6.1.4.1")
      assert {:ok, "1.3.6.1.4.1"} = ValueFormatter.format_value(:oid, oid_binary)
    end

    test "validates OID round-trip" do
      oid_string = "1.3.6.1.4.1.4491"
      assert {:ok, _binary} = ValueParser.validate_round_trip(:oid, oid_string)
    end

    test "handles invalid OID format" do
      assert {:error, reason} = ValueParser.parse_value(:oid, "invalid.oid")
      assert String.contains?(reason, "Invalid OID format")
    end

    test "handles OID with invalid arc values" do
      # First arc > 2
      assert {:error, reason} = ValueParser.parse_value(:oid, "5.100.1")
      assert String.contains?(reason, "first arc must be 0-2")
    end
  end

  describe "timestamp value type" do
    test "formats Unix timestamp correctly" do
      # January 1, 2020 00:00:00 UTC
      # 1577836800
      timestamp_binary = <<94, 19, 182, 0>>
      assert {:ok, formatted} = ValueFormatter.format_value(:timestamp, timestamp_binary)
      assert String.contains?(formatted, "2020")
    end

    test "parses Unix timestamp string" do
      assert {:ok, timestamp_binary} = ValueParser.parse_value(:timestamp, "1577836800")
      assert {:ok, formatted} = ValueFormatter.format_value(:timestamp, timestamp_binary)
      assert String.contains?(formatted, "2020")
    end

    test "parses ISO8601 timestamp" do
      iso_timestamp = "2020-01-01T00:00:00Z"
      assert {:ok, timestamp_binary} = ValueParser.parse_value(:timestamp, iso_timestamp)
      assert {:ok, _formatted} = ValueFormatter.format_value(:timestamp, timestamp_binary)
    end

    test "parses simple datetime format" do
      datetime_string = "2020-01-01T00:00:00Z"
      assert {:ok, timestamp_binary} = ValueParser.parse_value(:timestamp, datetime_string)
      assert {:ok, formatted} = ValueFormatter.format_value(:timestamp, timestamp_binary)
      assert String.contains?(formatted, "2020")
    end

    test "handles zero timestamp (not set)" do
      zero_timestamp = <<0, 0, 0, 0>>
      assert {:ok, "Not Set"} = ValueFormatter.format_value(:timestamp, zero_timestamp)
    end

    test "validates timestamp round-trip" do
      # Round trip test requires formatting and re-parsing
      timestamp_binary = <<94, 19, 182, 0>>
      {:ok, formatted} = ValueFormatter.format_value(:timestamp, timestamp_binary)
      assert {:ok, _binary} = ValueParser.validate_round_trip(:timestamp, formatted)
    end
  end

  describe "certificate value type" do
    test "formats certificate data in compact mode" do
      # Mock certificate data
      cert_data = <<48, 130, 3, 32, 48, 130, 2, 8>>

      assert {:ok, formatted} =
               ValueFormatter.format_value(:certificate, cert_data, format_style: :compact)

      assert String.contains?(formatted, "Certificate")
      assert String.contains?(formatted, "8 bytes")
    end

    test "formats certificate data in verbose mode" do
      # Mock ASN.1 SEQUENCE
      cert_data = <<48, 130, 3, 32>>

      assert {:ok, formatted} =
               ValueFormatter.format_value(:certificate, cert_data, format_style: :verbose)

      assert is_map(formatted)
    end

    test "parses hex-encoded certificate" do
      # Even number of hex chars
      hex_cert = "3082032030820200"
      assert {:ok, cert_binary} = ValueParser.parse_value(:certificate, hex_cert)
      assert is_binary(cert_binary)
    end

    test "parses base64-encoded certificate" do
      # Mock base64
      base64_cert = "MIIDIjCCAgoCCAA="
      assert {:ok, cert_binary} = ValueParser.parse_value(:certificate, base64_cert)
      assert is_binary(cert_binary)
    end

    test "handles PEM certificate format" do
      pem_cert = """
      -----BEGIN CERTIFICATE-----
      MIIDIjCCAgoCCAA=
      -----END CERTIFICATE-----
      """

      assert {:ok, cert_binary} = ValueParser.parse_value(:certificate, pem_cert)
      assert is_binary(cert_binary)
    end
  end

  describe "ASN.1 DER value type" do
    test "formats simple ASN.1 DER data as hex string that round-trips" do
      # ASN.1 INTEGER with value 42 (no OID) should format as hex string
      der_data = <<2, 1, 42>>

      assert {:ok, formatted} =
               ValueFormatter.format_value(:asn1_der, der_data, format_style: :compact)

      assert is_binary(formatted)
      refute String.contains?(formatted, "ASN.1 DER")

      # formatted hex must be parseable back to the original DER
      assert {:ok, parsed} = ValueParser.parse_value(:asn1_der, formatted)
      assert parsed == der_data
    end

    test "formats SNMP MIB object as %{oid, type, value} map that round-trips" do
      # Build ASN.1 DER for a simple SNMP MIB object via the parser
      snmp_map = %{
        oid: "1.3.6.1.4.1.4115.1.3.4.1.2.6.0",
        type: "INTEGER",
        value: 1
      }

      assert {:ok, der_binary} = ValueParser.parse_value(:asn1_der, snmp_map)

      # Formatter should return a map that ValueParser accepts again
      assert {:ok, formatted} =
               ValueFormatter.format_value(:asn1_der, der_binary, format_style: :compact)

      assert is_map(formatted)
      assert formatted.oid == snmp_map.oid
      assert formatted.type == snmp_map.type
      assert formatted.value == snmp_map.value

      # And that map must be parseable back into the same DER
      assert {:ok, parsed_from_map} = ValueParser.parse_value(:asn1_der, formatted)
      assert parsed_from_map == der_binary
    end

    test "formats multi-object ASN.1 DER as hex string that round-trips" do
      # Two INTEGERs in sequence (not a single SNMP object)
      der_data = <<2, 1, 1, 2, 1, 2>>

      assert {:ok, formatted} =
               ValueFormatter.format_value(:asn1_der, der_data, format_style: :compact)

      assert is_binary(formatted)
      refute String.contains?(formatted, "ASN.1 DER")

      # formatted hex must be parseable back to the original DER
      assert {:ok, parsed} = ValueParser.parse_value(:asn1_der, formatted)
      assert parsed == der_data
    end

    test "parses hex-encoded ASN.1 DER data" do
      # INTEGER 42
      hex_der = "02012A"
      assert {:ok, der_binary} = ValueParser.parse_value(:asn1_der, hex_der)
      assert der_binary == <<2, 1, 42>>
    end
  end

  describe "power quarter dB value type" do
    test "formats power quarter dB correctly" do
      # 40/4 = 10.0 dBmV
      power_binary = <<40>>
      assert {:ok, "10.0 dBmV"} = ValueFormatter.format_value(:power_quarter_db, power_binary)
    end

    test "parses power string with dBmV unit" do
      assert {:ok, power_binary} = ValueParser.parse_value(:power_quarter_db, "10.0 dBmV")
      assert power_binary == <<40>>
    end

    test "parses power string without unit" do
      assert {:ok, power_binary} = ValueParser.parse_value(:power_quarter_db, "10.0")
      assert power_binary == <<40>>
    end

    test "handles fractional power values" do
      assert {:ok, power_binary} = ValueParser.parse_value(:power_quarter_db, "10.25 dBmV")
      # 10.25 * 4 = 41
      assert power_binary == <<41>>
    end

    test "validates power round-trip" do
      power_string = "15.5 dBmV"
      assert {:ok, _binary} = ValueParser.validate_round_trip(:power_quarter_db, power_string)
    end

    test "handles power out of range" do
      assert {:error, reason} = ValueParser.parse_value(:power_quarter_db, "100.0 dBmV")
      assert String.contains?(reason, "out of range")
    end
  end

  describe "SNMP OID value type (alias)" do
    test "SNMP OID works as alias for OID" do
      oid_binary = <<43, 6, 1, 4, 1>>
      assert {:ok, formatted_oid} = ValueFormatter.format_value(:oid, oid_binary)
      assert {:ok, formatted_snmp} = ValueFormatter.format_value(:snmp_oid, oid_binary)
      assert formatted_oid == formatted_snmp
    end

    test "SNMP OID parsing works as alias" do
      oid_string = "1.3.6.1.4.1"
      assert {:ok, parsed_oid} = ValueParser.parse_value(:oid, oid_string)
      assert {:ok, parsed_snmp} = ValueParser.parse_value(:snmp_oid, oid_string)
      assert parsed_oid == parsed_snmp
    end
  end

  describe "value type support lists" do
    test "new value types are included in supported types" do
      formatter_types = ValueFormatter.get_supported_types()
      parser_types = ValueParser.get_supported_types()

      new_types = [:oid, :snmp_oid, :certificate, :asn1_der, :timestamp, :power_quarter_db]

      for type <- new_types do
        assert type in formatter_types, "#{type} not in ValueFormatter supported types"
        assert type in parser_types, "#{type} not in ValueParser supported types"
      end
    end

    test "value type support checking works" do
      assert ValueFormatter.supported_type?(:oid)
      assert ValueFormatter.supported_type?(:timestamp)
      assert ValueFormatter.supported_type?(:certificate)
      assert ValueFormatter.supported_type?(:asn1_der)
      assert ValueFormatter.supported_type?(:power_quarter_db)

      assert ValueParser.supported_type?(:oid)
      assert ValueParser.supported_type?(:timestamp)
      assert ValueParser.supported_type?(:certificate)
      assert ValueParser.supported_type?(:asn1_der)
      assert ValueParser.supported_type?(:power_quarter_db)

      refute ValueFormatter.supported_type?(:nonexistent_type)
      refute ValueParser.supported_type?(:nonexistent_type)
    end
  end

  describe "enum value type integration" do
    test "formats enum values correctly" do
      # Test with a simple enum
      enum_values = %{0 => "Disabled", 1 => "Enabled"}
      value_binary = <<1>>

      assert {:ok, "Enabled"} = ValueFormatter.format_value({:enum, enum_values}, value_binary)
    end

    test "formats enum with verbose style" do
      enum_values = %{0 => "Disabled", 1 => "Enabled"}
      value_binary = <<1>>

      assert {:ok, "1 (Enabled)"} =
               ValueFormatter.format_value({:enum, enum_values}, value_binary,
                 format_style: :verbose
               )
    end

    test "handles unknown enum values" do
      enum_values = %{0 => "Disabled", 1 => "Enabled"}
      # Unknown value
      value_binary = <<5>>

      assert {:ok, "5 (unknown)"} =
               ValueFormatter.format_value({:enum, enum_values}, value_binary)
    end

    test "parses enum by name" do
      enum_values = %{0 => "Disabled", 1 => "Enabled", 2 => "Auto"}

      assert {:ok, <<1>>} = ValueParser.parse_value({:enum, enum_values}, "Enabled")
      # Case insensitive
      assert {:ok, <<2>>} = ValueParser.parse_value({:enum, enum_values}, "auto")
    end

    test "parses enum by numeric value" do
      enum_values = %{0 => "Disabled", 1 => "Enabled"}

      assert {:ok, <<0>>} = ValueParser.parse_value({:enum, enum_values}, "0")
      assert {:ok, <<1>>} = ValueParser.parse_value({:enum, enum_values}, 1)
    end

    test "handles invalid enum input" do
      enum_values = %{0 => "Disabled", 1 => "Enabled"}

      assert {:error, reason} = ValueParser.parse_value({:enum, enum_values}, "Invalid")
      assert String.contains?(reason, "Invalid enum value")

      assert {:error, reason} = ValueParser.parse_value({:enum, enum_values}, "99")
      assert String.contains?(reason, "not in")
    end
  end

  describe "integration with existing value types" do
    test "all existing value types still work" do
      # Test a few existing types to ensure no regression
      assert {:ok, "591 MHz"} = ValueFormatter.format_value(:frequency, <<35, 57, 241, 192>>)
      assert {:ok, "192.168.1.100"} = ValueFormatter.format_value(:ipv4, <<192, 168, 1, 100>>)
      assert {:ok, "Enabled"} = ValueFormatter.format_value(:boolean, <<1>>)

      assert {:ok, _} = ValueParser.parse_value(:frequency, "591 MHz")
      assert {:ok, _} = ValueParser.parse_value(:ipv4, "192.168.1.100")
      assert {:ok, _} = ValueParser.parse_value(:boolean, "enabled")
    end
  end
end
