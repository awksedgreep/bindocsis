defmodule Bindocsis.Parsers.DocsisConfigfileYamlParser do
  @moduledoc """
  Parser for the YAML dialect used by the Perl `docsis-configfile` utility.

  This format is structurally different from Bindocsis' native `tlvs:` YAML.
  It uses top-level DOCSIS/PacketCable parameter names such as
  `SnmpMibObject`, `VendorSpecific`, and `MtaConfigDelimiter`.
  """

  import Bitwise

  alias Bindocsis.ValueParser

  @snmp_types ~w(INTEGER STRING NULLOBJ OBJECTID IPADDRESS COUNTER UNSIGNED TIMETICKS OPAQUE COUNTER64)

  @spec parse(String.t()) :: {:ok, [map()]} | {:error, String.t()}
  def parse(yaml_string) when is_binary(yaml_string) do
    case YamlElixir.read_from_string(yaml_string) do
      {:ok, parsed_yaml} when is_map(parsed_yaml) ->
        parse_document(parsed_yaml)

      {:ok, _other} ->
        {:error, "docsis-configfile YAML must decode to a root mapping"}

      {:error, error} ->
        {:error, "YAML parsing failed: #{inspect(error)}"}
    end
  end

  @spec supported_root_key?(String.t()) :: boolean()
  def supported_root_key?(key) when is_binary(key) do
    key in ["MtaConfigDelimiter", "SnmpMibObject", "VendorSpecific"]
  end

  defp parse_document(document) do
    unsupported_keys =
      document
      |> Map.keys()
      |> Enum.reject(&supported_root_key?/1)

    if unsupported_keys != [] do
      {:error,
       "Unsupported docsis-configfile YAML keys: #{Enum.join(Enum.sort(unsupported_keys), ", ")}"}
    else
      with {:ok, leading_delimiters, trailing_delimiters} <- parse_mta_delimiters(document),
           {:ok, body_tlvs} <- parse_body_tlvs(document) do
        {:ok, leading_delimiters ++ body_tlvs ++ trailing_delimiters}
      end
    end
  end

  defp parse_mta_delimiters(%{"MtaConfigDelimiter" => values}) do
    with {:ok, parsed_values} <- values |> List.wrap() |> parse_delimiter_values() do
      case parsed_values do
        [] -> {:ok, [], []}
        [first | rest] -> {:ok, [first], rest}
      end
    end
  end

  defp parse_mta_delimiters(_document), do: {:ok, [], []}

  defp parse_delimiter_values(values) do
    values
    |> Enum.with_index()
    |> Enum.reduce_while({:ok, []}, fn {value, index}, {:ok, acc} ->
      case parse_delimiter_tlv(value) do
        {:ok, tlv} ->
          {:cont, {:ok, acc ++ [tlv]}}

        {:error, reason} ->
          {:halt, {:error, "Invalid MtaConfigDelimiter at index #{index}: #{reason}"}}
      end
    end)
  end

  defp parse_delimiter_tlv(value) do
    with {:ok, delimiter} <- parse_uint8(value) do
      {:ok, %{type: 254, length: 1, value: <<delimiter>>}}
    end
  end

  defp parse_body_tlvs(document) do
    document
    |> Map.drop(["MtaConfigDelimiter"])
    |> Enum.sort_by(fn
      {"SnmpMibObject", _value} -> 11
      {"VendorSpecific", _value} -> 43
    end)
    |> Enum.reduce_while({:ok, []}, fn
      {"SnmpMibObject", entries}, {:ok, acc} ->
        case parse_snmp_entries(entries) do
          {:ok, tlvs} -> {:cont, {:ok, acc ++ tlvs}}
          {:error, reason} -> {:halt, {:error, reason}}
        end

      {"VendorSpecific", entries}, {:ok, acc} ->
        case parse_vendor_entries(entries) do
          {:ok, tlvs} -> {:cont, {:ok, acc ++ tlvs}}
          {:error, reason} -> {:halt, {:error, reason}}
        end
    end)
  end

  defp parse_snmp_entries(entries) do
    entries
    |> List.wrap()
    |> Enum.with_index()
    |> Enum.reduce_while({:ok, []}, fn {entry, index}, {:ok, acc} ->
      case parse_snmp_entry(entry) do
        {:ok, tlv} ->
          {:cont, {:ok, acc ++ [tlv]}}

        {:error, reason} ->
          {:halt, {:error, "Invalid SnmpMibObject at index #{index}: #{reason}"}}
      end
    end)
  end

  defp parse_snmp_entry(%{"oid" => oid} = entry) when is_binary(oid) do
    snmp_fields =
      entry
      |> Map.drop(["oid"])
      |> Enum.filter(fn {key, _value} -> key in @snmp_types end)

    case snmp_fields do
      [{type, value}] ->
        with {:ok, der_binary} <- encode_snmp_object(oid, type, value) do
          {:ok, %{type: 11, length: byte_size(der_binary), value: der_binary}}
        else
          {:error, reason} -> {:error, reason}
        end

      [] ->
        {:error, "entry must contain one SNMP value field plus oid"}

      _ ->
        {:error, "entry must contain exactly one SNMP value field plus oid"}
    end
  end

  defp parse_snmp_entry(_entry), do: {:error, "entry must be a mapping with an oid"}

  defp parse_vendor_entries(entries) do
    entries
    |> List.wrap()
    |> Enum.with_index()
    |> Enum.reduce_while({:ok, []}, fn {entry, index}, {:ok, acc} ->
      case parse_vendor_entry(entry) do
        {:ok, tlv} ->
          {:cont, {:ok, acc ++ [tlv]}}

        {:error, reason} ->
          {:halt, {:error, "Invalid VendorSpecific at index #{index}: #{reason}"}}
      end
    end)
  end

  defp parse_vendor_entry(%{"id" => id, "options" => options}) when is_list(options) do
    with {:ok, oui_binary} <- parse_vendor_id(id),
         {:ok, option_binary} <- parse_vendor_options(options) do
      value = <<8, byte_size(oui_binary)>> <> oui_binary <> option_binary
      {:ok, %{type: 43, length: byte_size(value), value: value}}
    end
  end

  defp parse_vendor_entry(_entry), do: {:error, "entry must contain id and options"}

  defp parse_vendor_options(options) when rem(length(options), 2) != 0 do
    {:error, "options must contain alternating type/value entries"}
  end

  defp parse_vendor_options(options) do
    options
    |> Enum.chunk_every(2)
    |> Enum.with_index()
    |> Enum.reduce_while({:ok, <<>>}, fn {[type, value], index}, {:ok, acc} ->
      with {:ok, option_type} <- parse_uint8(type),
           {:ok, value_binary} <- parse_binary_value(value) do
        encoded_option = <<option_type, byte_size(value_binary)>> <> value_binary
        {:cont, {:ok, acc <> encoded_option}}
      else
        {:error, reason} -> {:halt, {:error, "invalid vendor option #{index}: #{reason}"}}
      end
    end)
  end

  defp parse_binary_value(value) when is_binary(value) do
    trimmed = String.trim(value)

    if String.starts_with?(trimmed, "0x") do
      parse_hex_binary(trimmed)
    else
      case ValueParser.parse_value(:binary, value, []) do
        {:ok, binary} -> {:ok, binary}
        {:error, reason} -> {:error, reason}
      end
    end
  end

  defp parse_binary_value(value) when is_integer(value) do
    with {:ok, int_value} <- parse_uint8(value) do
      {:ok, <<int_value>>}
    end
  end

  defp parse_binary_value(_value), do: {:error, "value must be a binary or integer"}

  defp parse_vendor_id(id) when is_binary(id) do
    cleaned = String.replace(id, ~r/^(?:0x)/i, "") |> String.replace(~r/[^0-9A-Fa-f]/, "")

    case cleaned do
      <<a::binary-size(2), b::binary-size(2), c::binary-size(2)>> ->
        {:ok, <<String.to_integer(a, 16), String.to_integer(b, 16), String.to_integer(c, 16)>>}

      _ ->
        ValueParser.parse_value(:vendor_oui, id, [])
    end
  rescue
    ArgumentError -> {:error, "Invalid OUI format"}
  end

  defp parse_vendor_id(_id), do: {:error, "Invalid OUI format"}

  defp parse_hex_binary("0x" <> hex), do: parse_hex_binary(hex)
  defp parse_hex_binary("0X" <> hex), do: parse_hex_binary(hex)

  defp parse_hex_binary(hex) when is_binary(hex) do
    cleaned = String.replace(hex, ~r/\s+/, "")

    cond do
      cleaned == "" ->
        {:ok, <<>>}

      rem(byte_size(cleaned), 2) != 0 ->
        {:error, "hex value must contain an even number of characters"}

      true ->
        try do
          bytes =
            cleaned
            |> String.codepoints()
            |> Enum.chunk_every(2)
            |> Enum.map(fn [a, b] -> String.to_integer(a <> b, 16) end)

          {:ok, :binary.list_to_bin(bytes)}
        rescue
          ArgumentError -> {:error, "invalid hex value"}
        end
    end
  end

  defp encode_snmp_object(oid, type, value) do
    normalized_type = normalize_snmp_type(type)

    with {:ok, oid_binary} <- ValueParser.parse_value(:oid, oid, []),
         {:ok, tag, value_binary} <- encode_snmp_value(normalized_type, value) do
      oid_der = <<0x06>> <> encode_snmp_length(byte_size(oid_binary)) <> oid_binary
      value_der = <<tag>> <> encode_snmp_length(byte_size(value_binary)) <> value_binary
      sequence_content = oid_der <> value_der
      {:ok, <<0x30>> <> encode_snmp_length(byte_size(sequence_content)) <> sequence_content}
    end
  end

  defp normalize_snmp_type(type) when is_binary(type) do
    case String.upcase(type) do
      "IPADDRESS" -> "IpAddress"
      "COUNTER" -> "Counter32"
      "UNSIGNED" -> "Gauge32"
      "TIMETICKS" -> "TimeTicks"
      other -> other
    end
  end

  defp encode_snmp_value("INTEGER", value) when is_integer(value) do
    {:ok, 0x02, encode_snmp_integer32(value)}
  end

  defp encode_snmp_value("STRING", value) when is_binary(value) do
    with {:ok, binary} <- encode_snmp_string(value) do
      {:ok, 0x04, binary}
    end
  end

  defp encode_snmp_value("NULLOBJ", _value), do: {:ok, 0x05, <<>>}

  defp encode_snmp_value("OBJECTID", value) when is_binary(value) do
    with {:ok, oid_binary} <- ValueParser.parse_value(:oid, value, []) do
      {:ok, 0x06, oid_binary}
    end
  end

  defp encode_snmp_value("IpAddress", value) when is_binary(value) do
    case :inet.parse_address(String.to_charlist(value)) do
      {:ok, {a, b, c, d}} -> {:ok, 0x40, <<a, b, c, d>>}
      _ -> {:error, "Invalid IP address format: #{value}"}
    end
  end

  defp encode_snmp_value("Counter32", value) when is_integer(value) and value >= 0 do
    {:ok, 0x41, encode_snmp_uint32(value)}
  end

  defp encode_snmp_value("Gauge32", value) when is_integer(value) and value >= 0 do
    {:ok, 0x42, encode_snmp_uint32(value)}
  end

  defp encode_snmp_value("TimeTicks", value) when is_integer(value) and value >= 0 do
    {:ok, 0x43, encode_snmp_uint32(value)}
  end

  defp encode_snmp_value("OPAQUE", value) when is_integer(value) and value >= 0 do
    {:ok, 0x44, encode_snmp_uint32(value)}
  end

  defp encode_snmp_value("COUNTER64", value) when is_integer(value) do
    {:ok, 0x46, encode_snmp_bigint(value)}
  end

  defp encode_snmp_value(type, _value), do: {:error, "Unsupported ASN.1 type: #{type}"}

  defp encode_snmp_string("0x" <> hex), do: parse_hex_binary(hex)
  defp encode_snmp_string("0X" <> hex), do: parse_hex_binary(hex)
  defp encode_snmp_string(value), do: {:ok, value}

  defp encode_snmp_length(length) when length < 0x80, do: <<length>>
  defp encode_snmp_length(length) when length <= 0xFF, do: <<0x81, length>>
  defp encode_snmp_length(length) when length <= 0xFFFF, do: <<0x82, length::16>>
  defp encode_snmp_length(_length), do: raise(ArgumentError, "Too long snmp length")

  defp encode_snmp_integer32(value) do
    negative = value < 0
    encoded = do_encode_snmp_integer32(value &&& 0xFFFFFFFF, negative, [])

    cond do
      encoded == [] ->
        <<0>>

      not negative and hd(encoded) > 0x79 ->
        :binary.list_to_bin([0 | encoded])

      true ->
        :binary.list_to_bin(encoded)
    end
  end

  defp do_encode_snmp_integer32(0, _negative, acc), do: acc

  defp do_encode_snmp_integer32(value, negative, acc) do
    byte = value &&& 0xFF
    transformed = if negative, do: bxor(byte, 0xFF), else: byte
    do_encode_snmp_integer32(value >>> 8, negative, [transformed | acc])
  end

  defp encode_snmp_uint32(value) do
    encoded = do_encode_unsigned(value, [])

    cond do
      encoded == [] ->
        <<0>>

      hd(encoded) > 0x79 ->
        :binary.list_to_bin([0 | encoded])

      true ->
        :binary.list_to_bin(encoded)
    end
  end

  defp do_encode_unsigned(0, acc), do: acc

  defp do_encode_unsigned(value, acc) do
    do_encode_unsigned(value >>> 8, [value &&& 0xFF | acc])
  end

  defp encode_snmp_bigint(value) do
    negative = value < 0
    encoded = do_encode_unsigned(abs(value), [])

    bytes =
      if negative do
        case encoded do
          [] -> [0x80]
          _ -> Enum.map(encoded, &bxor(&1, 0xFF))
        end
      else
        encoded
      end

    :binary.list_to_bin(if(bytes == [], do: [0], else: bytes))
  end

  defp parse_uint8(value) when is_integer(value) and value >= 0 and value <= 255, do: {:ok, value}

  defp parse_uint8(value) when is_binary(value) do
    case Integer.parse(String.trim(value)) do
      {parsed, ""} when parsed >= 0 and parsed <= 255 -> {:ok, parsed}
      _ -> {:error, "expected integer 0-255"}
    end
  end

  defp parse_uint8(_value), do: {:error, "expected integer 0-255"}
end
