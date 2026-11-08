defmodule Bindocsis.MtaTlvLength do
  @moduledoc """
  TLV length fields of a PacketCable MTA configuration file.

  PKT-SP-PROV1.5-C01-191120 §9.1 ("MTA Configuration File") defines the
  length field per TLV type, not with the DOCSIS multi-byte markers that
  `Bindocsis.TlvLength` decodes:

  | TLV | length field | value                              |
  |-----|--------------|------------------------------------|
  | 11  | 1 byte       | SNMP variable binding              |
  | 64  | 2 bytes      | SNMP variable binding              |
  | 38  | 1 byte       | composite (sub-TLVs)               |
  | 254 | 1 byte       | 0x01 file start / 0xFF file end    |

  Vendor-specific TLV 43 (DOCSIS) uses a 1-byte length as well. "TLV type 64
  MUST be used when the length is greater than 254 bytes", so a TLV 11
  value is at most 254 bytes.

  Every other type is decoded with a 1-byte length, as DOCSIS tooling
  writes it. PROV1.5 §9.1 says an MTA skips a TLV it does not recognize
  "assuming the length field ... is 2 bytes", but the DOCSIS TLVs that real
  MTA files carry after the end marker (CM MIC 6, CMTS MIC 7) have 1-byte
  lengths, and reading them with 2 would misparse those files.

  A byte such as 0x81 is therefore a plain length of 129 here. It is never
  an extended-length marker.
  """

  @two_byte_types [64]
  @max_tlv11 254

  @doc "Bytes in the length field of `type` (1 or 2)."
  @spec field_size(non_neg_integer()) :: 1 | 2
  def field_size(type) when type in @two_byte_types, do: 2
  def field_size(_type), do: 1

  @doc "Largest value length `type` can carry."
  @spec max_length(non_neg_integer()) :: non_neg_integer()
  def max_length(type) when type in @two_byte_types, do: 0xFFFF
  def max_length(11), do: @max_tlv11
  def max_length(_type), do: 0xFF

  @doc """
  Encodes the length field for a TLV of `type`.

  Returns `{:error, reason}` when the value is too long for the type's length
  field (for TLV 11, longer than 254 bytes; use TLV 64 instead).
  """
  @spec encode(non_neg_integer(), non_neg_integer()) :: {:ok, binary()} | {:error, String.t()}
  def encode(type, length) when is_integer(length) and length >= 0 do
    max = max_length(type)

    cond do
      length > max and type == 11 ->
        {:error,
         "TLV 11 value is #{length} bytes; PKT-SP-PROV1.5 §9.1 requires TLV 64 for SNMP " <>
           "objects longer than #{@max_tlv11} bytes"}

      length > max ->
        {:error, "TLV #{type} value is #{length} bytes; its length field holds at most #{max}"}

      field_size(type) == 2 ->
        {:ok, <<length::16>>}

      true ->
        {:ok, <<length>>}
    end
  end

  def encode(_type, length), do: {:error, "Invalid TLV length: #{inspect(length)}"}

  @doc """
  Decodes the length field of a TLV of `type` from the front of `binary`.

  Returns `{:ok, length, rest}` with `rest` starting at the value bytes.
  """
  @spec decode(non_neg_integer(), binary()) ::
          {:ok, non_neg_integer(), binary()} | {:error, String.t()}
  def decode(type, <<length::16, rest::binary>>) when type in @two_byte_types,
    do: {:ok, length, rest}

  def decode(type, _binary) when type in @two_byte_types,
    do: {:error, "TLV #{type} needs a 2-byte length field"}

  def decode(_type, <<length, rest::binary>>), do: {:ok, length, rest}
  def decode(type, <<>>), do: {:error, "TLV #{type} is missing its length byte"}
end
