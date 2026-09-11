defmodule Bindocsis.Parsers.MtaBinaryParser do
  @moduledoc """
  Specialized binary parser for PacketCable MTA configuration files.

  Decodes the same TLV wire format as the DOCSIS parser (one shared length
  codec, `Bindocsis.TlvLength`) and annotates each TLV with PacketCable
  names and descriptions from `Bindocsis.MtaSpecs`.

  Malformed input is reported, never repaired by guessing: a TLV whose
  length exceeds the remaining bytes is an error (issue #9).
  """

  alias Bindocsis.MtaSpecs
  alias Bindocsis.TlvLength

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
    try do
      tlvs = parse_tlvs(binary, [])
      {:ok, Enum.reverse(tlvs)}
    rescue
      e -> {:error, "MTA binary parse error: #{Exception.message(e)}"}
    catch
      {:parse_error, reason} -> {:error, "#{inspect(reason)}"}
    end
  end

  # Base case: no more data
  defp parse_tlvs(<<>>, acc), do: acc

  # Insufficient data for TLV header
  defp parse_tlvs(data, _acc) when byte_size(data) < 2 do
    throw(
      {:parse_error, "Insufficient data for TLV header (need 2 bytes, have #{byte_size(data)})"}
    )
  end

  # Parse the next TLV
  defp parse_tlvs(data, acc) do
    case parse_single_tlv(data) do
      {:ok, tlv, remaining} ->
        parse_tlvs(remaining, [tlv | acc])

      {:error, reason} ->
        throw({:parse_error, reason})
    end
  end

  @doc """
  Parses a single TLV from the beginning of binary data.

  Length fields are decoded by the shared codec (`Bindocsis.TlvLength`), so
  `0x81`/`0x82`/`0x84` introduce extended lengths and every other byte is
  a plain one-byte length. A length that exceeds the remaining data is an
  error. Earlier versions guessed that an over-long `0x8X` length meant
  "the previous TLV had no length byte" and emitted a zero-length TLV that
  consumed one wire byte but re-encodes as two (issue #9); the parser now
  reports the malformed input instead of inventing a TLV.
  """
  @spec parse_single_tlv(binary()) :: {:ok, tlv(), binary()} | {:error, String.t()}
  def parse_single_tlv(<<type::8, rest::binary>> = data) when byte_size(data) >= 2 do
    case TlvLength.decode(rest) do
      {:ok, length, value_data} when byte_size(value_data) >= length ->
        <<value::binary-size(^length), remaining::binary>> = value_data
        {:ok, create_tlv(type, length, value), remaining}

      {:ok, length, value_data} ->
        {:error,
         "Insufficient data for TLV #{type} value (need #{length} bytes, have " <>
           "#{byte_size(value_data)})" <> ambiguity_hint(rest)}

      {:error, reason} ->
        {:error, "TLV #{type}: #{reason}"}
    end
  end

  def parse_single_tlv(data) when byte_size(data) < 2 do
    {:error, "Insufficient data for TLV header"}
  end

  # When the over-long length started with 0x84 (also PacketCable TLV type 84
  # "Line Package"), say so: the usual cause is a preceding TLV that was
  # written without its length byte.
  defp ambiguity_hint(<<0x84, _::binary>>),
    do:
      "; the length byte 0x84 may actually be TLV type 84 (Line Package) following a " <>
        "TLV that is missing its length byte"

  defp ambiguity_hint(_), do: ""

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
