defmodule Bindocsis.Tlv11SnmpTest do
  use ExUnit.Case, async: true

  alias Bindocsis.ValueFormatter
  alias Bindocsis.ValueParser

  @snmp_oid "1.3.6.1.2.1.69.1.2.1.4.1"
  @snmp_type "OCTET STRING"
  @snmp_value_hex "70726976617465" # "private"

  test "ASN.1 DER SNMP MIB object round-trips via formatter and parser" do
    # Build structured SNMP MIB object input for parser
    input = %{oid: @snmp_oid, type: @snmp_type, value: @snmp_value_hex}

    # Parse to DER binary
    {:ok, der} = ValueParser.parse_value(:asn1_der, input, [])

    # Format back to structured map
    {:ok, formatted} = ValueFormatter.format_value(:asn1_der, der, [])

    assert is_map(formatted)
    assert formatted.oid == @snmp_oid
    assert formatted.type == @snmp_type
    assert formatted.value == @snmp_value_hex

    # Parse formatted value again and ensure DER stays consistent
    {:ok, der2} = ValueParser.parse_value(:asn1_der, formatted, [])
    assert der2 == der
  end

  test "malformed ASN.1 DER falls back to hex and does not raise" do
    # This is intentionally not valid ASN.1, but should be treated as opaque bytes
    malformed = <<0x30, 0x03, 0x06, 0x01, 0x2a>>

    # Formatter should return a hex string, not raise or return a map
    {:ok, formatted} = ValueFormatter.format_value(:asn1_der, malformed, [])

    assert is_binary(formatted)
    # Hex uppercase by convention
    assert formatted == Base.encode16(malformed)

    # Parser should accept that hex and return the same bytes
    {:ok, der} = ValueParser.parse_value(:asn1_der, formatted, [])
    assert der == malformed
  end
end
