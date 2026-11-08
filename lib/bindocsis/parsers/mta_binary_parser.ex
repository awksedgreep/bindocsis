defmodule Bindocsis.Parsers.MtaBinaryParser do
  @moduledoc """
  Binary parser for PacketCable MTA configuration files.

  The wire format follows PKT-SP-PROV1.5-C01-191120 §9.1: each TLV has a
  one-byte type and a length field whose size depends on the type (see
  `Bindocsis.MtaTlvLength`). TLV 64 has a 2-byte length; every other type
  has a single length byte (so 0x81 is a length of 129, not an
  extended-length marker). A file starts with TLV 254 = 0x01 and ends with
  TLV 254 = 0xFF.

  Files built with DOCSIS tooling may carry a DOCSIS trailer after the
  MTA end marker: CM MIC (6) and CMTS MIC (7) TLVs, then a 0xFF
  End-of-Data byte and 0x00 padding. The MIC TLVs parse as ordinary TLVs.
  The 0xFF byte and the padding are not TLVs: `parse/1` stops there, and
  `parse_document/1` also returns those bytes as the `trailer` so a caller
  can write the file back byte for byte (`MtaBinaryGenerator`'s `:trailer`
  option).

  Malformed input is reported, never repaired by guessing (issue #9).
  """

  alias Bindocsis.MtaSpecs
  alias Bindocsis.MtaTlvLength

  @type tlv :: %{
          type: non_neg_integer(),
          length: non_neg_integer(),
          value: binary(),
          raw_value: binary()
        }

  @doc """
  Parses MTA binary configuration data into TLV structures.

  Returns {:ok, tlvs} or {:error, reason}
  """
  @spec parse(binary()) :: {:ok, [tlv()]} | {:error, String.t()}
  def parse(binary) when is_binary(binary) do
    with {:ok, %{tlvs: tlvs}} <- parse_document(binary), do: {:ok, tlvs}
  end

  @doc """
  Parses an MTA file into its TLVs and its DOCSIS trailer.

  `trailer` is `<<>>` when the file has no 0xFF End-of-Data byte; otherwise
  it is that byte followed by the zero padding, exactly as it was in the file.
  """
  @spec parse_document(binary()) ::
          {:ok, %{tlvs: [tlv()], trailer: binary()}} | {:error, String.t()}
  def parse_document(binary) when is_binary(binary) do
    try do
      {tlvs, trailer} = parse_tlvs(binary, [])
      {:ok, %{tlvs: Enum.reverse(tlvs), trailer: trailer}}
    rescue
      e -> {:error, "MTA binary parse error: #{Exception.message(e)}"}
    catch
      {:parse_error, reason} -> {:error, reason}
    end
  end

  defp parse_tlvs(<<>>, acc), do: {acc, <<>>}

  # DOCSIS End-of-Data byte: everything after it must be zero padding.
  defp parse_tlvs(<<0xFF, padding::binary>> = trailer, acc) do
    if padding == :binary.copy(<<0>>, byte_size(padding)) do
      {acc, trailer}
    else
      throw(
        {:parse_error,
         "#{byte_size(padding)} byte(s) after the 0xFF End-of-Data byte are not all zero padding"}
      )
    end
  end

  defp parse_tlvs(data, acc) do
    case parse_single_tlv(data) do
      {:ok, tlv, remaining} -> parse_tlvs(remaining, [tlv | acc])
      {:error, reason} -> throw({:parse_error, reason})
    end
  end

  @doc """
  Parses a single TLV from the beginning of binary data.

  A length that exceeds the remaining data is an error.
  """
  @spec parse_single_tlv(binary()) :: {:ok, tlv(), binary()} | {:error, String.t()}
  def parse_single_tlv(<<type::8, rest::binary>>) do
    case MtaTlvLength.decode(type, rest) do
      {:ok, length, value_data} when byte_size(value_data) >= length ->
        <<value::binary-size(^length), remaining::binary>> = value_data
        {:ok, create_tlv(type, length, value), remaining}

      {:ok, length, value_data} ->
        {:error,
         "Insufficient data for TLV #{type} value (need #{length} bytes, have " <>
           "#{byte_size(value_data)})"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def parse_single_tlv(<<>>), do: {:error, "Insufficient data for TLV header"}

  # Create a TLV struct with PacketCable-specific information
  defp create_tlv(type, length, value) do
    %{
      type: type,
      length: length,
      value: value,
      raw_value: value,
      name: MtaSpecs.get_tlv_name(type, "2.0"),
      description: MtaSpecs.get_tlv_description(type, "2.0"),
      mta_specific: MtaSpecs.mta_specific?(type)
    }
  end

  @doc """
  Debug helper to analyze the first few TLVs in an MTA binary file.
  """
  @spec debug_parse(binary(), integer()) :: map()
  def debug_parse(binary, max_tlvs \\ 5) do
    result = %{
      file_size: byte_size(binary),
      hex_dump: binary |> binary_part(0, min(32, byte_size(binary))) |> format_hex(),
      parse_attempts: [],
      status: :unknown,
      tlvs_parsed: 0,
      first_tlvs: [],
      error: nil
    }

    # Try parsing with our smart parser
    case parse(binary) do
      {:ok, tlvs} ->
        limited_tlvs = Enum.take(tlvs, max_tlvs)
        %{result | status: :success, tlvs_parsed: length(tlvs), first_tlvs: limited_tlvs}

      {:error, reason} ->
        %{result | status: :error, error: reason}
    end
  end

  # Format binary as hex string
  defp format_hex(binary) do
    binary
    |> :binary.bin_to_list()
    |> Enum.map(&Integer.to_string(&1, 16))
    |> Enum.map(&String.pad_leading(&1, 2, "0"))
    |> Enum.join(" ")
    |> String.upcase()
  end
end
