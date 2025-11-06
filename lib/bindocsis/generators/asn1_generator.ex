defmodule Bindocsis.Generators.Asn1Generator do
  @moduledoc """
  ASN.1 generator for PacketCable provisioning data files.

  This generator converts parsed ASN.1 objects back to binary BER 
  (Basic Encoding Rules) format for PacketCable MTA provisioning files.

  ## Supported Generation

  - INTEGER (0x02)
  - OCTET STRING (0x04)
  - OBJECT IDENTIFIER (0x06)
  - ENUMERATED (0x0A)
  - SEQUENCE (0x30)
  - SET (0x31)
  - PacketCable file header (0xFE)

  ## Input Format

  Takes ASN.1 objects in the format produced by Asn1Parser:

      %{
        type: 0x02,
        type_name: "INTEGER",
        length: 1,
        value: 42,
        raw_value: <<42>>,
        children: nil
      }
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

  @doc """
  Generates ASN.1 binary data from parsed objects.

  ## Parameters

  - `objects` - List of ASN.1 object maps
  - `opts` - Generation options

  ## Options

  - `:add_header` - Add PacketCable file header (default: true)
  - `:header_version` - Header version byte (default: 1)
  - `:header_type` - Header type byte (default: 1)

  ## Returns

  `{:ok, binary}` or `{:error, reason}`
  """
  @spec generate([asn1_object()], keyword()) :: {:ok, binary()} | {:error, String.t()}
  def generate(objects, opts \\ []) when is_list(objects) do
    try do
      binary_data =
        objects
        |> Enum.map(&encode_asn1_object/1)
        |> IO.iodata_to_binary()

      # Add PacketCable header if requested
      if Keyword.get(opts, :add_header, true) do
        header = create_packetcable_header(opts)
        {:ok, header <> binary_data}
      else
        {:ok, binary_data}
      end
    rescue
      e -> {:error, "ASN.1 generation error: #{Exception.message(e)}"}
    catch
      {:encode_error, reason} -> {:error, reason}
    end
  end

  @doc """
  Generates ASN.1 binary from a single object.
  """
  @spec generate_object(asn1_object()) :: {:ok, binary()} | {:error, String.t()}
  def generate_object(object) do
    try do
      binary = encode_asn1_object(object) |> IO.iodata_to_binary()
      {:ok, binary}
    rescue
      e -> {:error, "Object encoding error: #{Exception.message(e)}"}
    catch
      {:encode_error, reason} -> {:error, reason}
    end
  end

  # Create PacketCable file header
  defp create_packetcable_header(opts) do
    version = Keyword.get(opts, :header_version, 1)
    type = Keyword.get(opts, :header_type, 1)
    <<0xFE, version, type>>
  end

  # Encode a single ASN.1 object
  defp encode_asn1_object(%{type: type, children: children} = _object) when is_list(children) do
    # Constructed type (SEQUENCE, SET) - encode children first
    children_data =
      children
      |> Enum.map(&encode_asn1_object/1)
      |> IO.iodata_to_binary()

    [
      <<type>>,
      encode_asn1_length(byte_size(children_data)),
      children_data
    ]
  end

  defp encode_asn1_object(%{type: type, value: value, raw_value: raw_value, length: length}) do
    # Primitive type - encode the value with explicit length
    encoded_value = encode_asn1_value(type, value, raw_value)

    [
      <<type>>,
      encode_asn1_length(length),
      encoded_value
    ]
  end

  defp encode_asn1_object(%{type: type, value: value, raw_value: raw_value}) do
    # Primitive type - encode the value with calculated length
    encoded_value = encode_asn1_value(type, value, raw_value)

    [
      <<type>>,
      encode_asn1_length(byte_size(encoded_value)),
      encoded_value
    ]
  end

  defp encode_asn1_object(%{type: type, raw_value: raw_value}) do
    # Fallback: use raw value if available
    [
      <<type>>,
      encode_asn1_length(byte_size(raw_value)),
      raw_value
    ]
  end

  defp encode_asn1_object(object) do
    throw({:encode_error, "Invalid ASN.1 object format: #{inspect(object)}"})
  end

  # Encode ASN.1 length using BER rules
  defp encode_asn1_length(length) when length <= 127 do
    # Short form
    <<length>>
  end

  defp encode_asn1_length(length) when length <= 255 do
    # Long form - 1 byte
    <<0x81, length>>
  end

  defp encode_asn1_length(length) when length <= 65535 do
    # Long form - 2 bytes
    <<0x82, length::16>>
  end

  defp encode_asn1_length(length) when length <= 16_777_215 do
    # Long form - 3 bytes
    <<0x83, length::24>>
  end

  defp encode_asn1_length(length) when length <= 4_294_967_295 do
    # Long form - 4 bytes
    <<0x84, length::32>>
  end

  defp encode_asn1_length(length) when length > 4_294_967_295 do
    throw({:encode_error, "Length too large: #{length}"})
  end

  defp encode_asn1_length(_length) do
    throw({:encode_error, "Unsupported length encoding"})
  end

  # Encode ASN.1 values based on type
  defp encode_asn1_value(0x02, value, _raw) when is_integer(value) do
    # INTEGER
    encode_integer(value)
  end

  defp encode_asn1_value(0x0A, value, _raw) when is_integer(value) do
    # ENUMERATED (same as INTEGER)
    encode_integer(value)
  end

  defp encode_asn1_value(0x04, value, _raw) when is_binary(value) do
    # OCTET STRING
    value
  end

  defp encode_asn1_value(0x04, _value, raw) when is_binary(raw) do
    # OCTET STRING - use raw value
    raw
  end

  defp encode_asn1_value(0x06, {oid, _name}, _raw) when is_list(oid) do
    # OBJECT IDENTIFIER with name
    encode_object_identifier(oid)
  end

  defp encode_asn1_value(0x06, oid, _raw) when is_list(oid) do
    # OBJECT IDENTIFIER
    encode_object_identifier(oid)
  end

  defp encode_asn1_value(0xFE, %{version: version, type: type, data: data}, _raw) do
    # PacketCable header
    <<version, type>> <> data
  end

  defp encode_asn1_value(_tag, _value, raw) when is_binary(raw) do
    # Fallback: use raw value for unknown types
    raw
  end

  defp encode_asn1_value(tag, value, _raw) do
    Logger.warning(
      "Unknown ASN.1 tag 0x#{Integer.to_string(tag, 16)} with value #{inspect(value)}"
    )

    cond do
      is_binary(value) -> value
      is_integer(value) -> encode_integer(value)
      is_list(value) -> IO.iodata_to_binary(value)
      true -> <<>>
    end
  end

  # Encode INTEGER value
  defp encode_integer(0), do: <<0>>

  defp encode_integer(value) when value > 0 and value <= 127 do
    <<value>>
  end

  defp encode_integer(value) when value > 127 and value <= 255 do
    # Positive value that needs sign bit protection
    <<0, value>>
  end

  defp encode_integer(value) when value > 255 do
    # Multi-byte positive integer
    byte_count = ceil(:math.log2(value + 1) / 8)
    encode_positive_integer(value, byte_count)
  end

  defp encode_integer(value) when value < 0 and value >= -128 do
    # Single byte negative (two's complement)
    <<value::signed-8>>
  end

  defp encode_integer(value) when value < -128 do
    # Multi-byte negative integer
    bit_count = ceil(:math.log2(-value) + 1)
    byte_count = ceil(bit_count / 8)
    encode_negative_integer(value, byte_count)
  end

  defp encode_positive_integer(value, byte_count) do
    <<value::unsigned-big-size(byte_count)-unit(8)>>
  end

  defp encode_negative_integer(value, byte_count) do
    <<value::signed-big-size(byte_count)-unit(8)>>
  end

  # Encode OBJECT IDENTIFIER
  defp encode_object_identifier([]), do: <<>>

  defp encode_object_identifier([first, second | rest]) when first <= 2 and second <= 39 do
    # First byte encodes first two sub-identifiers
    first_byte = first * 40 + second

    rest_bytes = Enum.map(rest, &encode_oid_subidentifier/1)

    IO.iodata_to_binary([first_byte | rest_bytes])
  end

  defp encode_object_identifier(oid) do
    throw({:encode_error, "Invalid OID format: #{inspect(oid)}"})
  end

  # Encode OID sub-identifier using variable length encoding
  defp encode_oid_subidentifier(value) when value <= 127 do
    <<value>>
  end

  defp encode_oid_subidentifier(value) do
    encode_oid_multibyte(value, [])
  end

  defp encode_oid_multibyte(0, acc) do
    # Set continuation bit on all but last byte
    {last, rest} = List.pop_at(acc, -1)
    continued = Enum.map(rest, &(&1 ||| 0x80))
    IO.iodata_to_binary(continued ++ [last])
  end

  defp encode_oid_multibyte(value, acc) do
    byte = value &&& 0x7F
    encode_oid_multibyte(value >>> 7, [byte | acc])
  end

  @doc """
  Creates an ASN.1 object structure from simple values.

  Useful for creating objects programmatically before generation.
  """
  @spec create_object(non_neg_integer(), any()) :: asn1_object()
  def create_object(type, value) do
    raw_value = encode_asn1_value(type, value, <<>>)

    %{
      type: type,
      type_name: get_type_name(type),
      length: byte_size(raw_value),
      value: value,
      raw_value: raw_value,
      children: nil
    }
  end

  @doc """
  Creates a SEQUENCE object containing child objects.
  """
  @spec create_sequence([asn1_object()]) :: asn1_object()
  def create_sequence(children) when is_list(children) do
    %{
      type: 0x30,
      type_name: "SEQUENCE",
      # Will be calculated during encoding
      length: 0,
      value: :sequence,
      raw_value: <<>>,
      children: children
    }
  end

  # Get type name for display
  defp get_type_name(0x02), do: "INTEGER"
  defp get_type_name(0x04), do: "OCTET STRING"
  defp get_type_name(0x06), do: "OBJECT IDENTIFIER"
  defp get_type_name(0x0A), do: "ENUMERATED"
  defp get_type_name(0x30), do: "SEQUENCE"
  defp get_type_name(0x31), do: "SET"
  defp get_type_name(0xFE), do: "PacketCable File Header"
  defp get_type_name(type), do: "Unknown Type 0x#{Integer.to_string(type, 16)}"

  @doc """
  Helper to create common PacketCable objects.
  """
  def create_packetcable_integer(oid, value) when is_list(oid) and is_integer(value) do
    create_sequence([
      # OID
      create_object(0x06, oid),
      # INTEGER value
      create_object(0x02, value)
    ])
  end

  def create_packetcable_string(oid, value) when is_list(oid) and is_binary(value) do
    create_sequence([
      # OID
      create_object(0x06, oid),
      # OCTET STRING value
      create_object(0x04, value)
    ])
  end

  @doc """
  Debug helper to validate generated ASN.1 data.
  """
  @spec validate_generated(binary()) :: {:ok, [asn1_object()]} | {:error, String.t()}
  def validate_generated(binary) do
    # Try to parse the generated data to validate it
    Bindocsis.Parsers.Asn1Parser.parse(binary)
  end
end
