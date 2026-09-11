defmodule Bindocsis.TlvLength do
  @moduledoc """
  The single TLV length-field codec shared by every parser and generator.

  A DOCSIS TLV length field is one byte. Three first-byte values are
  multi-byte length markers, following the ASN.1 BER long-form convention:

  | first byte | following bytes | length range        |
  |------------|-----------------|---------------------|
  | `0x00-0x7F`| none            | 0-127               |
  | `0x81`     | 1               | 0-255               |
  | `0x82`     | 2               | 0-65535             |
  | `0x84`     | 4               | 0-4294967295        |
  | any other  | none            | 128-255 (plain)     |

  Every other first byte (including `0x80`, `0x83` and `0x85`-`0xFF`) is a
  plain single-byte length, matching the files produced by common DOCSIS
  tooling. When encoding, lengths 128-255 are written as one byte except
  the three marker values themselves, which are written as `0x81 nn` so the
  decoder cannot mistake them for markers.

  Before this module existed the binary generator, the config parser, the
  TLV enricher and the MTA generator each carried their own copy of these
  rules and they disagreed (issues #6, #7).
  """

  @markers [0x81, 0x82, 0x84]

  @doc "Encodes a length field."
  @spec encode(non_neg_integer()) :: binary()
  def encode(length) when is_integer(length) and length >= 0 and length <= 127, do: <<length>>
  def encode(length) when length in @markers, do: <<0x81, length>>
  def encode(length) when is_integer(length) and length >= 128 and length <= 255, do: <<length>>

  def encode(length) when is_integer(length) and length >= 256 and length <= 0xFFFF,
    do: <<0x82, length::16>>

  def encode(length) when is_integer(length) and length >= 0x10000 and length <= 0xFFFFFFFF,
    do: <<0x84, length::32>>

  def encode(length) do
    raise ArgumentError, "TLV length out of range: #{inspect(length)} (max 4294967295)"
  end

  @doc "Number of bytes `encode/1` produces for `length` (1, 2, 3 or 5)."
  @spec field_size(non_neg_integer()) :: 1 | 2 | 3 | 5
  def field_size(length) when is_integer(length) and length >= 0 and length <= 127, do: 1
  def field_size(length) when length in @markers, do: 2
  def field_size(length) when is_integer(length) and length >= 128 and length <= 255, do: 1
  def field_size(length) when is_integer(length) and length >= 256 and length <= 0xFFFF, do: 3

  def field_size(length) when is_integer(length) and length >= 0x10000 and length <= 0xFFFFFFFF,
    do: 5

  @doc """
  Decodes a length field from the front of `binary`.

  Returns `{:ok, length, rest}` where `rest` starts at the value bytes, or
  `{:error, reason}` when the marker's extension bytes are missing.
  """
  @spec decode(binary()) :: {:ok, non_neg_integer(), binary()} | {:error, String.t()}
  def decode(<<first, rest::binary>>) when first <= 0x7F, do: {:ok, first, rest}
  def decode(<<0x81, length::8, rest::binary>>), do: {:ok, length, rest}
  def decode(<<0x82, length::16, rest::binary>>), do: {:ok, length, rest}
  def decode(<<0x84, length::32, rest::binary>>), do: {:ok, length, rest}

  def decode(<<marker, rest::binary>>) when marker in @markers do
    {:error,
     "insufficient data for extended length: marker 0x#{Integer.to_string(marker, 16)} needs " <>
       "#{marker - 0x80} more byte(s), have #{byte_size(rest)}"}
  end

  def decode(<<first, rest::binary>>), do: {:ok, first, rest}
  def decode(<<>>), do: {:error, "missing length byte"}

  @doc "Total encoded size of a TLV with the given value length: type + length field + value."
  @spec encoded_size(non_neg_integer()) :: pos_integer()
  def encoded_size(length), do: 1 + field_size(length) + length
end
