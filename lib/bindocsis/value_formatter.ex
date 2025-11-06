defmodule Bindocsis.ValueFormatter do
  import Bitwise

  @moduledoc """
  Value formatting module for converting binary TLV values to human-readable formats.

  Provides smart formatting based on TLV value types, converting raw binary data
  into meaningful representations like frequencies in MHz, IP addresses in dotted
  decimal notation, and bandwidth values in Mbps/Gbps.

  ## Supported Value Types

  - `:uint8`, `:uint16`, `:uint32` - Integer values
  - `:ipv4`, `:ipv6` - IP addresses  
  - `:frequency` - Frequencies (Hz → MHz/GHz)
  - `:bandwidth` - Bandwidth (bps → Mbps/Gbps)
  - `:boolean` - Boolean values (0/1 → "disabled"/"enabled")
  - `:mac_address` - MAC addresses (binary → "00:11:22:33:44:55")
  - `:duration` - Time durations (seconds → human readable)
  - `:percentage` - Percentage values
  - `:string` - String values
  - `:binary` - Binary data (hex representation)
  - `:compound` - Compound TLVs (structured display)

  ## Examples

      iex> Bindocsis.ValueFormatter.format_value(:frequency, <<35, 57, 241, 192>>)
      {:ok, "591 MHz"}
      
      iex> Bindocsis.ValueFormatter.format_value(:ipv4, <<192, 168, 1, 100>>)
      {:ok, "192.168.1.100"}
      
      iex> Bindocsis.ValueFormatter.format_value(:boolean, <<1>>)
      {:ok, "Enabled"}
  """

  @type value_type :: atom()
  @type binary_value :: binary()
  @type formatted_value :: String.t() | map() | list()
  @type format_result :: {:ok, formatted_value()} | {:error, String.t()}

  @doc """
  Formats a binary value based on its type.

  ## Parameters

  - `value_type` - The type of value to format (:frequency, :ipv4, etc.)
  - `binary_value` - The raw binary data to format
  - `opts` - Optional formatting options

  ## Options

  - `:precision` - Decimal precision for floating point values (default: 2)
  - `:unit_preference` - Preferred units (e.g., :mhz for frequencies)
  - `:format_style` - Format style (:compact, :verbose) (default: :compact)

  ## Returns

  - `{:ok, formatted_string}` - Successfully formatted value
  - `{:error, reason}` - Formatting error with reason
  """
  @spec format_value(value_type(), binary_value(), keyword()) :: format_result()
  def format_value(value_type, binary_value, opts \\ [])

  # Integer types
  def format_value(:uint8, <<value::8>>, _opts) do
    {:ok, Integer.to_string(value)}
  end

  # Handle uint8 with wrong size - just convert as concatenated hex without spaces
  # This is a fallback for incorrectly typed data
  def format_value(:uint8, binary_value, _opts)
      when is_binary(binary_value) and byte_size(binary_value) > 1 do
    # Convert to hex without spaces so it can be parsed back
    {:ok, Base.encode16(binary_value)}
  end

  def format_value(:uint16, <<value::16>>, _opts) do
    {:ok, Integer.to_string(value)}
  end

  def format_value(:uint32, <<value::32>>, _opts) do
    {:ok, Integer.to_string(value)}
  end

  # Frequency formatting (Hz → MHz/GHz)
  def format_value(:frequency, <<frequency_hz::32>>, opts) do
    precision = Keyword.get(opts, :precision, 2)
    unit_pref = Keyword.get(opts, :unit_preference, :auto)

    formatted =
      case {frequency_hz, unit_pref} do
        {hz, :hz} -> "#{hz} Hz"
        {hz, :mhz} -> "#{format_decimal(hz / 1_000_000, precision)} MHz"
        {hz, :ghz} -> "#{format_decimal(hz / 1_000_000_000, precision)} GHz"
        {hz, :auto} -> format_frequency_auto(hz, precision)
      end

    {:ok, formatted}
  end

  # IP Address formatting
  def format_value(:ipv4, <<a, b, c, d>>, _opts) do
    {:ok, "#{a}.#{b}.#{c}.#{d}"}
  end

  def format_value(:ipv4, binary_value, _opts) when byte_size(binary_value) != 4 do
    {:error, "Invalid IPv4 address length: expected 4 bytes, got #{byte_size(binary_value)}"}
  end

  def format_value(:ipv6, <<a::16, b::16, c::16, d::16, e::16, f::16, g::16, h::16>>, _opts) do
    formatted =
      [a, b, c, d, e, f, g, h]
      |> Enum.map(&Integer.to_string(&1, 16))
      |> Enum.map(&String.downcase/1)
      |> Enum.join(":")

    {:ok, formatted}
  end

  # Object Identifier (OID) formatting
  def format_value(:oid, binary_value, _opts) when is_binary(binary_value) do
    case decode_oid(binary_value) do
      {:ok, oid_list} -> {:ok, Enum.join(oid_list, ".")}
      {:error, _} -> {:ok, Base.encode16(binary_value)}
    end
  end

  # Bandwidth formatting (bps → Mbps/Gbps)
  def format_value(:bandwidth, <<bandwidth_bps::32>>, opts) do
    precision = Keyword.get(opts, :precision, 2)
    unit_pref = Keyword.get(opts, :unit_preference, :auto)

    formatted =
      case {bandwidth_bps, unit_pref} do
        {bps, :bps} -> "#{bps} bps"
        {bps, :kbps} -> "#{format_decimal(bps / 1_000, precision)} Kbps"
        {bps, :mbps} -> "#{format_decimal(bps / 1_000_000, precision)} Mbps"
        {bps, :gbps} -> "#{format_decimal(bps / 1_000_000_000, precision)} Gbps"
        {bps, :auto} -> format_bandwidth_auto(bps, precision)
      end

    {:ok, formatted}
  end

  # Boolean formatting
  def format_value(:boolean, <<0>>, _opts), do: {:ok, "Disabled"}
  def format_value(:boolean, <<1>>, _opts), do: {:ok, "Enabled"}

  # Boolean with wrong size - fall back to hex string
  def format_value(:boolean, binary_value, _opts) when byte_size(binary_value) > 1 do
    # Boolean should be 1 byte, but we got more - format as hex string
    hex_string =
      binary_value
      |> :binary.bin_to_list()
      |> Enum.map(&Integer.to_string(&1, 16))
      |> Enum.map(&String.pad_leading(&1, 2, "0"))
      |> Enum.map(&String.upcase/1)
      |> Enum.join(" ")

    {:ok, hex_string}
  end

  # MAC Address formatting
  def format_value(:mac_address, <<a, b, c, d, e, f>>, _opts) do
    formatted =
      [a, b, c, d, e, f]
      |> Enum.map(&Integer.to_string(&1, 16))
      |> Enum.map(&String.pad_leading(&1, 2, "0"))
      |> Enum.map(&String.upcase/1)
      |> Enum.join(":")

    {:ok, formatted}
  end

  def format_value(:mac_address, binary_value, _opts) when byte_size(binary_value) != 6 do
    {:error, "Invalid MAC address length: expected 6 bytes, got #{byte_size(binary_value)}"}
  end

  # Duration formatting (seconds → human readable)
  def format_value(:duration, <<seconds::32>>, _opts) do
    formatted = format_duration(seconds)
    {:ok, formatted}
  end

  # Percentage formatting
  def format_value(:percentage, <<value::8>>, _opts) do
    {:ok, "#{value}%"}
  end

  # Power in quarter dB units formatting
  def format_value(:power_quarter_db, <<value::8>>, opts) do
    precision = Keyword.get(opts, :precision, 1)
    power_db = value / 4.0
    formatted = Float.round(power_db, precision)
    {:ok, "#{formatted} dBmV"}
  end

  # Enum formatting with value lookup
  def format_value({:enum, enum_values}, binary_value, opts) when is_map(enum_values) do
    format_enum_with_values(binary_value, enum_values, opts)
  end

  def format_value({:enum, enum_values, value_type}, binary_value, opts)
      when is_map(enum_values) do
    format_enum_with_values(binary_value, enum_values, opts, value_type)
  end

  # String formatting
  def format_value(:string, binary_value, _opts) when is_binary(binary_value) do
    # Check if the binary is valid UTF-8 and printable
    case String.valid?(binary_value) and printable_string?(binary_value) do
      true -> {:ok, String.trim_trailing(binary_value, <<0>>)}
      false -> format_value(:binary, binary_value, [])
    end
  end

  # Binary data formatting (hex representation)
  def format_value(:binary, binary_value, opts) when is_binary(binary_value) do
    format_style = Keyword.get(opts, :format_style, :compact)

    formatted =
      case format_style do
        :compact -> Base.encode16(binary_value)
        :verbose -> format_hex_verbose(binary_value)
      end

    {:ok, formatted}
  end

  # Service Flow Reference formatting
  def format_value(:service_flow_ref, <<0, ref::8>>, _opts) do
    {:ok, "Service Flow ##{ref}"}
  end

  def format_value(:service_flow_ref, <<ref::16>>, _opts) do
    {:ok, "Service Flow ##{ref}"}
  end

  # Vendor OUI formatting
  def format_value(:vendor_oui, <<a, b, c>>, _opts) do
    oui =
      [a, b, c]
      |> Enum.map(&Integer.to_string(&1, 16))
      |> Enum.map(&String.pad_leading(&1, 2, "0"))
      |> Enum.map(&String.upcase/1)
      |> Enum.join(":")

    vendor_name = get_vendor_name(<<a, b, c>>)

    formatted =
      case vendor_name do
        :unknown -> oui
        name -> "#{name} (#{oui})"
      end

    {:ok, formatted}
  end

  # Compound TLV formatting (structured display)
  def format_value(:compound, binary_value, opts) when is_binary(binary_value) do
    format_style = Keyword.get(opts, :format_style, :compact)

    case format_style do
      :compact ->
        {:ok, "<Compound TLV: #{byte_size(binary_value)} bytes>"}

      :verbose ->
        # Parse compound TLV into subtlvs for bidirectional support
        case Bindocsis.parse(binary_value, enhanced: false) do
          {:ok, subtlvs} ->
            {:ok, %{"subtlvs" => format_subtlvs_for_human_config(subtlvs, opts)}}

          {:error, _} ->
            {:ok,
             %{
               "type" => "Compound TLV",
               "size" => byte_size(binary_value),
               "data" => Base.encode16(binary_value)
             }}
        end
    end
  end

  # Marker types (like End-of-Data)
  def format_value(:marker, <<>>, _opts) do
    {:ok, "<End-of-Data>"}
  end

  # Certificate/ASN.1 DER formatting
  def format_value(:certificate, binary_value, opts) when is_binary(binary_value) do
    format_style = Keyword.get(opts, :format_style, :compact)

    case format_style do
      :compact ->
        {:ok, "<Certificate: #{byte_size(binary_value)} bytes>"}

      :verbose ->
        case decode_certificate_info(binary_value) do
          {:ok, cert_info} ->
            {:ok, cert_info}

          {:error, _} ->
            {:ok,
             %{
               type: "Certificate",
               size: byte_size(binary_value),
               data: Base.encode16(binary_value)
             }}
        end
    end
  end

  # ASN.1 DER encoded data formatting
  def format_value(:asn1_der, binary_value, opts) when is_binary(binary_value) do
    format_style = Keyword.get(opts, :format_style, :compact)

    # Try to parse multiple ASN.1 objects in sequence (common for SNMP MIB objects)
    case parse_multiple_asn1_objects(binary_value) do
      {:ok, [%{type_name: "OBJECT IDENTIFIER", value: oid_list} | rest]} when rest != [] ->
        # SNMP MIB object with OID followed by value - return structured data
        [value_obj] = rest

        {:ok,
         %{
           oid: Enum.join(oid_list, "."),
           type: value_obj.type_name,
           value: format_asn1_object_value(value_obj)
         }}

      {:ok, [%{type_name: "OBJECT IDENTIFIER", value: oid_list}]} ->
        # For standalone OIDs, show the parsed value
        {:ok, Enum.join(oid_list, ".")}

      {:ok, objects} when length(objects) > 1 ->
        # Multiple ASN.1 objects - format as structured data
        {:ok,
         %{
           type: "Multiple ASN.1 Objects",
           objects:
             Enum.map(objects, fn obj ->
               %{type: obj.type_name, value: format_asn1_object_value(obj)}
             end)
         }}

      # Fallback to single object parsing
      _ ->
        case Bindocsis.Parsers.Asn1Parser.parse_single_asn1_object(binary_value) do
          {:ok, %{type_name: "OBJECT IDENTIFIER", value: oid_list}, _} ->
            # For standalone OIDs, show the parsed value regardless of format_style
            {:ok, Enum.join(oid_list, ".")}

          {:ok,
           %{
             type_name: "SEQUENCE",
             children: [
               %{type_name: "OBJECT IDENTIFIER", value: oid_list},
               %{type_name: "INTEGER", value: int_value}
             ]
           }, _} ->
            # SNMP MIB object with OID and integer value - return structured data
            {:ok,
             %{
               oid: Enum.join(oid_list, "."),
               type: "INTEGER",
               value: int_value
             }}

          {:ok,
           %{
             type_name: "SEQUENCE",
             children: [
               %{type_name: "OBJECT IDENTIFIER", value: oid_list},
               %{type_name: "OCTET STRING", value: octet_value}
             ]
           }, _} ->
            # SNMP MIB object with OID and octet string value - return structured data
            {:ok,
             %{
               oid: Enum.join(oid_list, "."),
               type: "OCTET STRING",
               value: Base.encode16(octet_value)
             }}

          {:ok,
           %{
             type_name: "SEQUENCE",
             children: [%{type_name: "OBJECT IDENTIFIER", value: oid_list} | other_values]
           }, _} ->
            # SNMP MIB object with OID and other value types - return structured data
            case other_values do
              [%{type_name: type_name, value: val}] ->
                {:ok,
                 %{
                   oid: Enum.join(oid_list, "."),
                   type: type_name,
                   value: val
                 }}

              vals ->
                {:ok,
                 %{
                   oid: Enum.join(oid_list, "."),
                   type: "SEQUENCE",
                   value: Enum.map(vals, &%{type: &1.type_name, value: &1.value})
                 }}
            end

          {:ok, _parsed_object, _} ->
            # Other ASN.1 structures - fall back to original decode_asn1_structure logic
            case decode_asn1_structure(binary_value) do
              {:ok, %{asn1_type: "OBJECT IDENTIFIER", value: oid_value}} ->
                {:ok, oid_value}

              {:ok, structure} when format_style == :verbose ->
                {:ok, structure}

              {:ok, _structure} ->
                {:ok, "<ASN.1 DER: #{byte_size(binary_value)} bytes>"}

              {:error, _} ->
                case format_style do
                  :compact ->
                    {:ok, "<ASN.1 DER: #{byte_size(binary_value)} bytes>"}

                  :verbose ->
                    {:ok,
                     %{
                       type: "ASN.1 DER Data",
                       size: byte_size(binary_value),
                       data: Base.encode16(binary_value)
                     }}
                end
            end

          {:error, _} ->
            case format_style do
              :compact ->
                {:ok, "<ASN.1 DER: #{byte_size(binary_value)} bytes>"}

              :verbose ->
                {:ok,
                 %{
                   type: "ASN.1 DER Data",
                   size: byte_size(binary_value),
                   data: Base.encode16(binary_value)
                 }}
            end
        end
    end
  end

  # Timestamp formatting (Unix timestamp)
  def format_value(:timestamp, <<timestamp::32>>, opts) when timestamp > 0 do
    format_style = Keyword.get(opts, :format_style, :compact)

    try do
      datetime = DateTime.from_unix!(timestamp)

      formatted =
        case format_style do
          :verbose -> DateTime.to_iso8601(datetime)
          _ -> DateTime.to_string(datetime)
        end

      {:ok, formatted}
    rescue
      _ -> {:ok, "Invalid timestamp: #{timestamp}"}
    end
  end

  def format_value(:timestamp, <<0, 0, 0, 0>>, _opts) do
    {:ok, "Not Set"}
  end

  # SNMP OID formatting (alias for :oid)
  def format_value(:snmp_oid, binary_value, opts) when is_binary(binary_value) do
    format_value(:oid, binary_value, opts)
  end

  # Vendor-specific formatting
  def format_value(:vendor, binary_value, opts) when is_binary(binary_value) do
    case binary_value do
      <<oui::binary-size(3), data::binary>> ->
        vendor_name = get_vendor_name(oui)
        # Format OUI as hex string with colons for structured output
        _format_style = Keyword.get(opts, :format_style, :compact)

        oui_formatted =
          oui
          |> :binary.bin_to_list()
          |> Enum.map(&Integer.to_string(&1, 16))
          |> Enum.map(&String.pad_leading(&1, 2, "0"))
          |> Enum.map(&String.upcase/1)
          |> Enum.join(":")

        # Always return structured data for JSON/editing workflow compatibility
        # Use string keys for JSON compatibility
        vendor_data = %{
          "oui" => oui_formatted,
          "data" => Base.encode16(data)
        }

        formatted =
          case vendor_name do
            :unknown -> vendor_data
            name -> Map.put(vendor_data, "vendor_name", name)
          end

        {:ok, formatted}

      _ ->
        format_value(:binary, binary_value, opts)
    end
  end

  # Unknown or unsupported types - fallback to binary
  def format_value(:unknown, binary_value, opts) do
    format_value(:binary, binary_value, opts)
  end

  def format_value(_unknown_type, binary_value, opts) when is_binary(binary_value) do
    format_value(:binary, binary_value, opts)
  end

  # Handle invalid binary data
  def format_value(_type, _invalid_binary, _opts) do
    {:error, "Invalid binary data for formatting"}
  end

  # Helper to format subtlvs for HumanConfig compatibility
  defp format_subtlvs_for_human_config(subtlvs, _opts) do
    Enum.map(subtlvs, fn subtlv ->
      hex_value = Base.encode16(subtlv.value)

      %{
        type: subtlv.type,
        length: subtlv.length,
        value: hex_value,
        # Use hex string as formatted_value - ValueParser can handle this for binary types
        formatted_value: hex_value,
        # Force value_type to binary so ValueParser treats it as hex data
        value_type: "binary"
      }
    end)
  end

  @doc """
  Formats a raw value (integer, binary, etc.) to a human-readable string.

  This is used when you have a raw value (like from parsing) rather than
  a specific binary representation.
  """
  @spec format_raw_value(value_type(), any(), keyword()) :: format_result()
  def format_raw_value(value_type, raw_value, opts \\ [])

  def format_raw_value(:frequency, frequency_hz, opts) when is_integer(frequency_hz) do
    precision = Keyword.get(opts, :precision, 2)
    formatted = format_frequency_auto(frequency_hz, precision)
    {:ok, formatted}
  end

  def format_raw_value(:bandwidth, bandwidth_bps, opts) when is_integer(bandwidth_bps) do
    precision = Keyword.get(opts, :precision, 2)
    formatted = format_bandwidth_auto(bandwidth_bps, precision)
    {:ok, formatted}
  end

  def format_raw_value(:boolean, 0, _opts), do: {:ok, "Disabled"}
  def format_raw_value(:boolean, 1, _opts), do: {:ok, "Enabled"}
  def format_raw_value(:boolean, false, _opts), do: {:ok, "Disabled"}
  def format_raw_value(:boolean, true, _opts), do: {:ok, "Enabled"}

  def format_raw_value(:percentage, value, _opts) when is_integer(value) do
    {:ok, "#{value}%"}
  end

  def format_raw_value(_type, value, _opts) when is_binary(value) do
    {:ok, value}
  end

  def format_raw_value(_type, value, _opts) do
    {:ok, to_string(value)}
  end

  # Private helper functions

  defp format_frequency_auto(hz, precision) do
    cond do
      hz >= 1_000_000_000 -> "#{format_decimal(hz / 1_000_000_000, precision)} GHz"
      hz >= 1_000_000 -> "#{format_decimal(hz / 1_000_000, precision)} MHz"
      hz >= 1_000 -> "#{format_decimal(hz / 1_000, precision)} KHz"
      true -> "#{hz} Hz"
    end
  end

  defp format_bandwidth_auto(bps, precision) do
    cond do
      bps >= 1_000_000_000 -> "#{format_decimal(bps / 1_000_000_000, precision)} Gbps"
      bps >= 1_000_000 -> "#{format_decimal(bps / 1_000_000, precision)} Mbps"
      bps >= 1_000 -> "#{format_decimal(bps / 1_000, precision)} Kbps"
      true -> "#{bps} bps"
    end
  end

  defp format_duration(seconds) do
    cond do
      seconds >= 86400 -> "#{div(seconds, 86400)} day(s)"
      seconds >= 3600 -> "#{div(seconds, 3600)} hour(s)"
      seconds >= 60 -> "#{div(seconds, 60)} minute(s)"
      true -> "#{seconds} second(s)"
    end
  end

  defp format_decimal(value, precision) do
    if precision == 0 or value == trunc(value) do
      Integer.to_string(trunc(value))
    else
      :erlang.float_to_binary(value, decimals: precision)
    end
  end

  defp format_hex_verbose(binary) do
    lines =
      binary
      |> :binary.bin_to_list()
      |> Enum.chunk_every(16)
      |> Enum.with_index()
      |> Enum.map(fn {chunk, index} ->
        offset = String.pad_leading(Integer.to_string(index * 16, 16), 4, "0")

        hex =
          chunk
          |> Enum.map(&String.pad_leading(Integer.to_string(&1, 16), 2, "0"))
          |> Enum.join(" ")

        ascii = chunk |> Enum.map(&printable_char/1) |> Enum.join("")
        "#{offset}: #{String.pad_trailing(hex, 47)} #{ascii}"
      end)

    # Join with \n for proper JSON escaping (will be escaped by JSON encoder)
    Enum.join(lines, "\n")
  end

  defp printable_char(byte) when byte >= 32 and byte <= 126, do: <<byte>>
  defp printable_char(_), do: "."

  # Check if a binary string contains only printable characters
  defp printable_string?(binary) when is_binary(binary) do
    binary
    |> :binary.bin_to_list()
    |> Enum.all?(&((&1 >= 32 and &1 <= 126) or &1 == 0))
  end

  # Private helper functions for ASN.1 parsing

  @spec parse_multiple_asn1_objects(binary()) :: {:ok, [map()]} | {:error, String.t()}
  defp parse_multiple_asn1_objects(binary_data) do
    try do
      objects = parse_asn1_objects_recursively(binary_data, [])
      {:ok, Enum.reverse(objects)}
    rescue
      _ -> {:error, "Failed to parse multiple ASN.1 objects"}
    end
  end

  defp parse_asn1_objects_recursively(<<>>, acc), do: acc

  defp parse_asn1_objects_recursively(binary, acc) do
    case Bindocsis.Parsers.Asn1Parser.parse_single_asn1_object(binary) do
      {:ok, object, remaining} ->
        parse_asn1_objects_recursively(remaining, [object | acc])

      {:error, _} ->
        acc
    end
  end

  @spec format_asn1_object_value(map()) :: any()
  defp format_asn1_object_value(%{type_name: "OBJECT IDENTIFIER", value: oid_list}) do
    Enum.join(oid_list, ".")
  end

  defp format_asn1_object_value(%{type_name: "INTEGER", value: int_value}) do
    int_value
  end

  defp format_asn1_object_value(%{type_name: "OCTET STRING", value: octet_value}) do
    Base.encode16(octet_value)
  end

  defp format_asn1_object_value(%{type_name: "APPLICATION " <> _tag, value: app_value})
       when is_binary(app_value) do
    Base.encode16(app_value)
  end

  defp format_asn1_object_value(%{type_name: type_name, value: value}) when is_binary(value) do
    "#{type_name}: #{Base.encode16(value)}"
  end

  defp format_asn1_object_value(%{value: value}) do
    value
  end

  # Private helper functions for new value types

  @spec decode_oid(binary()) :: {:ok, [non_neg_integer()]} | {:error, String.t()}
  defp decode_oid(<<>>), do: {:error, "Empty OID"}

  defp decode_oid(<<first_byte::8, rest::binary>>) do
    # First byte encodes first two sub-identifiers: (40 * first) + second
    first_subid = div(first_byte, 40)
    second_subid = rem(first_byte, 40)

    case decode_oid_subidentifiers(rest, []) do
      {:ok, remaining_subids} ->
        {:ok, [first_subid, second_subid | remaining_subids]}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @spec decode_oid_subidentifiers(binary(), [non_neg_integer()]) ::
          {:ok, [non_neg_integer()]} | {:error, String.t()}
  defp decode_oid_subidentifiers(<<>>, acc), do: {:ok, Enum.reverse(acc)}

  defp decode_oid_subidentifiers(data, acc) do
    case decode_oid_subidentifier(data, 0) do
      {:ok, subid, remaining} ->
        decode_oid_subidentifiers(remaining, [subid | acc])

      {:error, reason} ->
        {:error, reason}
    end
  end

  @spec decode_oid_subidentifier(binary(), non_neg_integer()) ::
          {:ok, non_neg_integer(), binary()} | {:error, String.t()}
  defp decode_oid_subidentifier(<<>>, _acc), do: {:error, "Incomplete OID subidentifier"}

  defp decode_oid_subidentifier(<<byte::8, rest::binary>>, acc) do
    new_acc = acc * 128 + (byte &&& 0x7F)

    if (byte &&& 0x80) == 0 do
      # Last byte of sub-identifier
      {:ok, new_acc, rest}
    else
      # More bytes follow
      decode_oid_subidentifier(rest, new_acc)
    end
  end

  @spec decode_certificate_info(binary()) :: {:ok, map()} | {:error, String.t()}
  defp decode_certificate_info(binary_data) do
    # Try to extract basic certificate information using ASN.1 parser
    alias Bindocsis.Parsers.Asn1Parser

    case Asn1Parser.parse_single_asn1_object(binary_data) do
      {:ok, object, _} ->
        {:ok,
         %{
           type: "X.509 Certificate",
           size: byte_size(binary_data),
           asn1_type: object.type_name,
           length: object.length
         }}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @spec decode_asn1_structure(binary()) :: {:ok, map()} | {:error, String.t()}
  defp decode_asn1_structure(binary_data) do
    # Try to decode ASN.1 DER structure
    alias Bindocsis.Parsers.Asn1Parser

    case Asn1Parser.parse_single_asn1_object(binary_data) do
      {:ok, object, _} ->
        {:ok,
         %{
           type: "ASN.1 DER Structure",
           size: byte_size(binary_data),
           asn1_type: object.type_name,
           length: object.length,
           value: format_asn1_value(object.value)
         }}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @spec format_asn1_value(any()) :: String.t()
  defp format_asn1_value(value) when is_list(value) do
    # OID list
    Enum.join(value, ".")
  end

  defp format_asn1_value(value) when is_integer(value) do
    Integer.to_string(value)
  end

  defp format_asn1_value(value) when is_binary(value) and byte_size(value) <= 32 do
    # Small binary - show as string if printable, otherwise hex
    if String.printable?(value) do
      "\"#{value}\""
    else
      Base.encode16(value)
    end
  end

  defp format_asn1_value(value) when is_binary(value) do
    "<#{byte_size(value)} bytes>"
  end

  defp format_asn1_value(value) do
    inspect(value)
  end

  # Vendor OUI to name mapping (partial list)
  defp get_vendor_name(<<0x00, 0x00, 0x0C>>), do: "Cisco Systems"
  defp get_vendor_name(<<0x00, 0x10, 0x95>>), do: "Broadcom Corporation"
  defp get_vendor_name(<<0x00, 0x20, 0xA6>>), do: "Proxim Corporation"
  defp get_vendor_name(<<0x00, 0x60, 0xB0>>), do: "Hewlett Packard"
  defp get_vendor_name(<<0x00, 0x90, 0x4C>>), do: "Epigram"
  defp get_vendor_name(<<0x00, 0xE0, 0x2B>>), do: "Extreme Networks"
  defp get_vendor_name(_), do: :unknown

  @doc """
  Gets all supported value types that can be formatted.
  """
  @spec get_supported_types() :: [value_type()]
  def get_supported_types do
    [
      :uint8,
      :uint16,
      :uint32,
      :ipv4,
      :ipv6,
      :frequency,
      :bandwidth,
      :boolean,
      :mac_address,
      :duration,
      :percentage,
      :string,
      :binary,
      :service_flow_ref,
      :vendor_oui,
      :compound,
      :marker,
      :vendor,
      :oid,
      :snmp_oid,
      :certificate,
      :asn1_der,
      :timestamp,
      :power_quarter_db
    ]
  end

  @doc """
  Checks if a value type is supported for formatting.
  """
  @spec supported_type?(value_type()) :: boolean()
  def supported_type?(value_type) do
    value_type in get_supported_types()
  end

  # Private enum formatting functions

  @spec format_enum_with_values(binary(), map(), keyword()) :: format_result()
  defp format_enum_with_values(binary_value, enum_values, opts) do
    # Default to uint8 for enum extraction
    format_enum_with_values(binary_value, enum_values, opts, :uint8)
  end

  @spec format_enum_with_values(binary(), map(), keyword(), atom()) :: format_result()
  defp format_enum_with_values(binary_value, enum_values, opts, value_type) do
    format_style = Keyword.get(opts, :format_style, :compact)

    # Extract the raw integer value based on the underlying type
    raw_value =
      case value_type do
        :uint8 when byte_size(binary_value) == 1 ->
          <<val::8>> = binary_value
          val

        :uint16 when byte_size(binary_value) == 2 ->
          <<val::16>> = binary_value
          val

        :uint32 when byte_size(binary_value) == 4 ->
          <<val::32>> = binary_value
          val

        _ ->
          nil
      end

    case raw_value do
      val when is_integer(val) ->
        case Map.get(enum_values, val) do
          nil ->
            case format_style do
              :verbose -> {:ok, "#{val} (Unknown enum value)"}
              _ -> {:ok, "#{val} (unknown)"}
            end

          enum_name ->
            case format_style do
              :verbose -> {:ok, "#{val} (#{enum_name})"}
              _ -> {:ok, enum_name}
            end
        end

      _ ->
        {:error, "Invalid binary data for enum type #{value_type}"}
    end
  end
end
