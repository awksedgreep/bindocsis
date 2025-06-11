defmodule Bindocsis.Parsers.Asn1Parser do
  @moduledoc """
  ASN.1 parser for PacketCable provisioning data files.
  
  This parser handles ASN.1 BER (Basic Encoding Rules) encoded data commonly
  found in PacketCable MTA provisioning files. These files typically contain
  SNMP MIB objects with PacketCable-specific configuration data.
  
  ## Supported ASN.1 Types
  
  - INTEGER (0x02)
  - OCTET STRING (0x04) 
  - OBJECT IDENTIFIER (0x06)
  - ENUMERATED (0x0A)
  - SEQUENCE (0x30)
  - SET (0x31)
  - PacketCable file header (0xFE)
  
  ## File Format
  
  PacketCable provisioning files typically start with:
  - 0xFE 0x01 0x01 (file header)
  - Followed by ASN.1 encoded SNMP objects
  """

  require Logger
  import Bitwise

  @type asn1_object :: %{
    type: non_neg_integer(),
    type_name: String.t(),
    length: non_neg_integer(),
    value: any(),
    raw_value: binary(),
    children: [asn1_object()] | nil
  }

  # ASN.1 Universal tag mappings
  @asn1_tags %{
    0x01 => "BOOLEAN",
    0x02 => "INTEGER", 
    0x03 => "BIT STRING",
    0x04 => "OCTET STRING",
    0x05 => "NULL",
    0x06 => "OBJECT IDENTIFIER",
    0x07 => "OBJECT DESCRIPTOR",
    0x08 => "EXTERNAL",
    0x09 => "REAL",
    0x0A => "ENUMERATED",
    0x0B => "EMBEDDED PDV",
    0x0C => "UTF8String",
    0x0D => "RELATIVE-OID",
    0x10 => "SEQUENCE",
    0x11 => "SET",
    0x12 => "NumericString",
    0x13 => "PrintableString",
    0x14 => "T61String",
    0x15 => "VideotexString",
    0x16 => "IA5String",
    0x17 => "UTCTime",
    0x18 => "GeneralizedTime",
    0x19 => "GraphicString",
    0x1A => "VisibleString",
    0x1B => "GeneralString",
    0x1C => "UniversalString",
    0x1D => "CHARACTER STRING",
    0x1E => "BMPString",
    0x30 => "SEQUENCE",
    0x31 => "SET",
    0xFE => "PacketCable File Header"
  }

  # PacketCable MIB OID mappings (common ones)
  @packetcable_oids %{
    [1, 3, 6, 1, 4, 1, 4491] => "CableLabs",
    [1, 3, 6, 1, 4, 1, 4491, 2] => "PacketCable",
    [1, 3, 6, 1, 4, 1, 4491, 2, 2] => "PacketCable MTA MIB",
    [1, 3, 6, 1, 4, 1, 40755] => "Motorola/ARRIS",
    [1, 3, 6, 1, 4, 1, 41011] => "Cisco",
    [1, 3, 6, 1, 4, 1, 4115] => "Thomson/Technicolor"
  }

  @doc """
  Parses ASN.1 encoded PacketCable provisioning data.
  
  Returns {:ok, objects} where objects is a list of parsed ASN.1 objects,
  or {:error, reason} if parsing fails.
  """
  @spec parse(binary()) :: {:ok, [asn1_object()]} | {:error, String.t()}
  def parse(binary) when is_binary(binary) do
    try do
      # Try to parse ASN.1 objects regardless of format detection
      # This makes the parser more flexible for plain ASN.1 data
      objects = parse_asn1_objects(binary, [])
      case objects do
        [] -> {:error, "No valid ASN.1 objects found"}
        _ -> {:ok, Enum.reverse(objects)}
      end
    rescue
      e -> {:error, "ASN.1 parse error: #{Exception.message(e)}"}
    catch
      {:parse_error, reason} -> {:error, reason}
    end
  end

  @doc """
  Detects if binary data appears to be PacketCable ASN.1 format.
  """
  @spec detect_packetcable_format(binary()) :: :ok | {:error, String.t()}
  def detect_packetcable_format(<<0xFE, 0x01, 0x01, _rest::binary>>) do
    :ok
  end
  
  def detect_packetcable_format(<<0xFE, _rest::binary>>) do
    :ok  # Other PacketCable file variants
  end
  
  def detect_packetcable_format(<<0x30, _rest::binary>>) do
    :ok  # Starts with SEQUENCE, might be raw ASN.1
  end
  
  def detect_packetcable_format(_) do
    {:error, "Not a recognized PacketCable ASN.1 format"}
  end

  # Parse ASN.1 objects from binary data
  defp parse_asn1_objects(<<>>, acc), do: acc
  
  defp parse_asn1_objects(data, acc) when byte_size(data) < 2 do
    Logger.debug("Insufficient data for ASN.1 object: #{byte_size(data)} bytes remaining")
    acc
  end
  
  defp parse_asn1_objects(data, acc) do
    case parse_single_asn1_object(data) do
      {:ok, object, remaining} ->
        parse_asn1_objects(remaining, [object | acc])
      {:error, reason} ->
        Logger.warning("Failed to parse ASN.1 object: #{reason}")
        acc
    end
  end

  @doc """
  Parses a single ASN.1 object from binary data.
  
  Returns {:ok, object, remaining_data} or {:error, reason}.
  """
  @spec parse_single_asn1_object(binary()) :: {:ok, asn1_object(), binary()} | {:error, String.t()}
  def parse_single_asn1_object(<<type::8, rest::binary>>) do
    case decode_asn1_length(rest) do
      {:ok, length, value_and_remaining} ->
        if byte_size(value_and_remaining) >= length do
          <<value::binary-size(length), remaining::binary>> = value_and_remaining
          
          object = %{
            type: type,
            type_name: get_type_name(type),
            length: length,
            raw_value: value,
            value: decode_asn1_value(type, value),
            children: decode_asn1_children(type, value)
          }
          
          {:ok, object, remaining}
        else
          {:error, "Insufficient data for ASN.1 value (need #{length} bytes, have #{byte_size(value_and_remaining)})"}
        end
      
      {:error, reason} ->
        {:error, "Length decode error: #{reason}"}
    end
  end
  
  def parse_single_asn1_object(_) do
    {:error, "Insufficient data for ASN.1 tag"}
  end

  # Decode ASN.1 length field (BER encoding)
  defp decode_asn1_length(<<length_byte::8, rest::binary>>) when length_byte <= 0x7F do
    # Short form: length is the byte value itself
    {:ok, length_byte, rest}
  end
  
  defp decode_asn1_length(<<0x80, _rest::binary>>) do
    {:error, "Indefinite length not supported"}
  end
  
  defp decode_asn1_length(<<length_byte::8, rest::binary>>) when length_byte > 0x80 do
    # Long form: first byte indicates number of length bytes
    num_length_bytes = length_byte - 0x80
    
    if byte_size(rest) >= num_length_bytes do
      <<length_bytes::binary-size(num_length_bytes), remaining::binary>> = rest
      length = decode_multibyte_length(length_bytes)
      {:ok, length, remaining}
    else
      {:error, "Insufficient data for long-form length"}
    end
  end
  
  defp decode_asn1_length(_) do
    {:error, "Invalid length encoding"}
  end

  # Decode multi-byte length value (big-endian)
  defp decode_multibyte_length(bytes) do
    bytes
    |> :binary.bin_to_list()
    |> Enum.reduce(0, fn byte, acc -> acc * 256 + byte end)
  end

  # Get human-readable name for ASN.1 type
  defp get_type_name(type) do
    Map.get(@asn1_tags, type, "Unknown Type 0x#{Integer.to_string(type, 16)}")
  end

  # Decode ASN.1 value based on tag type
  defp decode_asn1_value(0x02, value), do: decode_integer(value)
  defp decode_asn1_value(0x04, value), do: decode_octet_string(value)
  defp decode_asn1_value(0x06, value), do: decode_object_identifier(value)
  defp decode_asn1_value(0x0A, value), do: decode_integer(value)  # ENUMERATED
  defp decode_asn1_value(0x30, _value), do: :sequence  # Will have children
  defp decode_asn1_value(0x31, _value), do: :set       # Will have children
  defp decode_asn1_value(0xFE, value), do: decode_packetcable_header(value)
  defp decode_asn1_value(_tag, value) when byte_size(value) <= 64 do
    # For unknown/string types, try to decode as string if printable
    if printable_string?(value) do
      String.trim(value, <<0>>)  # Remove null terminators
    else
      value
    end
  end
  defp decode_asn1_value(_tag, value), do: value

  # Decode children for constructed types (SEQUENCE, SET)
  defp decode_asn1_children(tag, value) when tag in [0x30, 0x31] do
    # SEQUENCE or SET - parse children
    case parse_asn1_objects(value, []) do
      [] -> nil
      children -> Enum.reverse(children)
    end
  end
  defp decode_asn1_children(_tag, _value), do: nil

  # Decode INTEGER
  defp decode_integer(<<>>), do: 0
  defp decode_integer(<<byte::8>>) when byte <= 0x7F, do: byte
  defp decode_integer(<<byte::8>>) when byte > 0x7F, do: byte - 256  # Two's complement
  defp decode_integer(value) do
    # Multi-byte integer (big-endian, two's complement)
    <<first_byte::8, _rest::binary>> = value
    is_negative = (first_byte &&& 0x80) != 0
    
    unsigned_value = value
    |> :binary.bin_to_list()
    |> Enum.reduce(0, fn byte, acc -> acc * 256 + byte end)
    
    if is_negative do
      # Convert from two's complement
      max_value = :math.pow(256, byte_size(value)) |> round()
      unsigned_value - max_value
    else
      unsigned_value
    end
  end

  # Decode OCTET STRING
  defp decode_octet_string(value) do
    if printable_string?(value) do
      String.trim(value, <<0>>)
    else
      value
    end
  end

  # Decode OBJECT IDENTIFIER
  defp decode_object_identifier(<<>>), do: []
  defp decode_object_identifier(<<first_byte::8, rest::binary>>) do
    # First byte encodes first two sub-identifiers: (40 * first) + second
    first_subid = div(first_byte, 40)
    second_subid = rem(first_byte, 40)
    
    remaining_subids = decode_oid_subidentifiers(rest, [])
    oid = [first_subid, second_subid | remaining_subids]
    
    # Try to resolve to known PacketCable OID
    case Map.get(@packetcable_oids, oid) do
      nil -> oid
      name -> {oid, name}
    end
  end

  # Decode remaining OID sub-identifiers
  defp decode_oid_subidentifiers(<<>>, acc), do: Enum.reverse(acc)
  defp decode_oid_subidentifiers(data, acc) do
    case decode_oid_subidentifier(data, 0) do
      {:ok, subid, remaining} ->
        decode_oid_subidentifiers(remaining, [subid | acc])
      :error ->
        Enum.reverse(acc)
    end
  end

  # Decode single OID sub-identifier (variable length encoding)
  defp decode_oid_subidentifier(<<>>, _acc), do: :error
  defp decode_oid_subidentifier(<<byte::8, rest::binary>>, acc) do
    new_acc = (acc * 128) + (byte &&& 0x7F)
    
    if (byte &&& 0x80) == 0 do
      # Last byte of sub-identifier
      {:ok, new_acc, rest}
    else
      # More bytes follow
      decode_oid_subidentifier(rest, new_acc)
    end
  end

  # Decode PacketCable file header
  defp decode_packetcable_header(<<version::8, type::8, rest::binary>>) do
    %{
      version: version,
      type: type,
      data: rest
    }
  end
  defp decode_packetcable_header(<<version::8, type::8>>) do
    %{
      version: version,
      type: type,
      data: <<>>
    }
  end
  defp decode_packetcable_header(<<version::8>>) do
    %{
      version: version,
      type: 1,  # default type
      data: <<>>
    }
  end
  defp decode_packetcable_header(value), do: value

  # Check if binary contains printable ASCII characters
  defp printable_string?(binary) when byte_size(binary) == 0, do: false
  defp printable_string?(binary) do
    binary
    |> :binary.bin_to_list()
    |> Enum.all?(fn 
      0 -> true  # Allow null bytes
      byte when byte >= 32 and byte <= 126 -> true  # Printable ASCII
      byte when byte == 9 or byte == 10 or byte == 13 -> true  # Tab, LF, CR
      _ -> false
    end)
  end

  @doc """
  Formats parsed ASN.1 objects into a human-readable structure.
  """
  @spec format_objects([asn1_object()]) :: [map()]
  def format_objects(objects) when is_list(objects) do
    Enum.map(objects, &format_object/1)
  end

  defp format_object(object) do
    base = %{
      type: "0x#{Integer.to_string(object.type, 16)}",
      type_name: object.type_name,
      length: object.length,
      value: format_value(object.value)
    }
    
    if object.children do
      Map.put(base, :children, format_objects(object.children))
    else
      base
    end
  end

  defp format_value({oid, name}) when is_list(oid) do
    "#{Enum.join(oid, ".")} (#{name})"
  end
  defp format_value(oid) when is_list(oid) do
    Enum.join(oid, ".")
  end
  defp format_value(value) when is_binary(value) and byte_size(value) > 64 do
    "<<#{byte_size(value)} bytes>>"
  end
  defp format_value(value), do: value

  @doc """
  Debug helper to show detailed analysis of an ASN.1 file.
  """
  @spec debug_parse(binary(), keyword()) :: map()
  def debug_parse(binary, opts \\ []) do
    max_objects = Keyword.get(opts, :max_objects, 10)
    
    result = %{
      file_size: byte_size(binary),
      file_format: detect_format_details(binary),
      hex_preview: format_hex_preview(binary, 64),
      status: :unknown,
      objects_parsed: 0,
      objects: [],
      error: nil
    }
    
    case parse(binary) do
      {:ok, objects} ->
        limited_objects = Enum.take(objects, max_objects)
        %{result |
          status: :success,
          objects_parsed: length(objects),
          objects: format_objects(limited_objects)
        }
      
      {:error, reason} ->
        %{result |
          status: :error,
          error: reason
        }
    end
  end

  defp detect_format_details(<<0xFE, version::8, type::8, _rest::binary>>) do
    "PacketCable file (version #{version}, type #{type})"
  end
  defp detect_format_details(<<0x30, _rest::binary>>) do
    "ASN.1 SEQUENCE (raw format)"
  end
  defp detect_format_details(_) do
    "Unknown ASN.1 format"
  end

  defp format_hex_preview(binary, max_bytes) do
    bytes_to_show = min(byte_size(binary), max_bytes)
    <<chunk::binary-size(bytes_to_show), _rest::binary>> = binary
    
    chunk
    |> :binary.bin_to_list()
    |> Enum.map(&Integer.to_string(&1, 16))
    |> Enum.map(&String.pad_leading(&1, 2, "0"))
    |> Enum.join(" ")
    |> String.upcase()
  end
end