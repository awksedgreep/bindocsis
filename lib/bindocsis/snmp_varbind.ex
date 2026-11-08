defmodule Bindocsis.SnmpVarbind do
  @moduledoc """
  SNMP variable bindings as carried in TLV 11 (SNMP MIB Object) and, in
  PacketCable MTA files, TLV 64: a BER `SEQUENCE { OBJECT IDENTIFIER, value }`.

  Values use the type names of the docsis-configfile YAML dialect
  (`SnmpMibObject` entries), and the encoding is exactly the one that
  dialect's parser writes, so a variable binding edited here and one edited
  as YAML give the same bytes.

  Values are strings, as typed in a form:

  - integer types (`INTEGER`, `COUNTER`, `UNSIGNED`, `TIMETICKS`, `OPAQUE`,
    `COUNTER64`) take a decimal number
  - `STRING` takes text, or `0x`-prefixed hex for bytes that are not
    printable text
  - `OBJECTID` takes a dotted OID, `IPADDRESS` a dotted IPv4 address
  - `NULLOBJ` ignores the value

  ## Examples

      iex> {:ok, der} = Bindocsis.SnmpVarbind.encode("1.3.6.1.2.1.1.1.0", "INTEGER", "7")
      iex> Base.encode16(der)
      "300D06082B060102010101000201" <> "07"
      iex> Bindocsis.SnmpVarbind.decode(der)
      {:ok, %{oid: "1.3.6.1.2.1.1.1.0", type: "INTEGER", value: "7"}}
  """

  alias Bindocsis.Generators.DocsisConfigfileYamlGenerator
  alias Bindocsis.Parsers.DocsisConfigfileYamlParser

  @types ~w(INTEGER STRING NULLOBJ OBJECTID IPADDRESS COUNTER UNSIGNED TIMETICKS OPAQUE COUNTER64)

  # SNMPv2-SMI (RFC 2578): Integer32 is signed 32-bit; Counter32, Gauge32
  # (UNSIGNED) and TimeTicks are unsigned 32-bit; Counter64 is unsigned 64-bit.
  # OPAQUE carries an integer in this dialect and is held to 32 bits like the
  # other application types the parser encodes with its 32-bit encoder.
  @ranges %{
    "INTEGER" => {-2_147_483_648, 2_147_483_647},
    "COUNTER" => {0, 4_294_967_295},
    "UNSIGNED" => {0, 4_294_967_295},
    "TIMETICKS" => {0, 4_294_967_295},
    "OPAQUE" => {0, 4_294_967_295},
    "COUNTER64" => {0, 18_446_744_073_709_551_615}
  }

  @type t :: %{oid: String.t(), type: String.t(), value: String.t()}

  @doc "The value type names, in docsis-configfile spelling."
  @spec types() :: [String.t()]
  def types, do: @types

  @doc """
  Decodes a variable binding. Returns an error for BER the
  docsis-configfile dialect has no type name for.
  """
  @spec decode(binary()) :: {:ok, t()} | {:error, String.t()}
  def decode(binary) when is_binary(binary) do
    with {:ok, {type, value, oid}} <- DocsisConfigfileYamlGenerator.decode_varbind(binary) do
      {:ok, %{oid: oid, type: type, value: value_string(value)}}
    end
  end

  @doc "Encodes a variable binding from form strings."
  @spec encode(String.t(), String.t(), String.t()) :: {:ok, binary()} | {:error, String.t()}
  def encode(oid, type, value) when is_binary(oid) and is_binary(type) and is_binary(value) do
    type = String.upcase(String.trim(type))

    with :ok <- check_type(type),
         {:ok, oid} <- check_oid(String.trim(oid)),
         {:ok, value} <- typed_value(type, value) do
      DocsisConfigfileYamlParser.encode_varbind(oid, type, value)
    end
  end

  defp value_string({:text, s}), do: s
  defp value_string({:hex, s}), do: s
  defp value_string(n) when is_integer(n), do: Integer.to_string(n)
  defp value_string(s) when is_binary(s), do: s

  defp check_type(type) when type in @types, do: :ok
  defp check_type(type), do: {:error, "unknown SNMP type #{inspect(type)}"}

  defp check_oid(oid) do
    if String.match?(oid, ~r/\A[0-2](\.\d+)+\z/),
      do: {:ok, oid},
      else: {:error, "OID must be dotted numbers, e.g. 1.3.6.1.2.1.1.1.0"}
  end

  defp typed_value(type, value) when is_map_key(@ranges, type) do
    {min, max} = Map.fetch!(@ranges, type)

    case Integer.parse(String.trim(value)) do
      {n, ""} when n >= min and n <= max -> {:ok, n}
      {_n, ""} -> {:error, "#{type} must be between #{min} and #{max}"}
      _ -> {:error, "#{type} must be a whole number"}
    end
  end

  defp typed_value("IPADDRESS", value) do
    case :inet.parse_ipv4strict_address(String.to_charlist(String.trim(value))) do
      {:ok, _} -> {:ok, String.trim(value)}
      _ -> {:error, "IPADDRESS must be a dotted IPv4 address"}
    end
  end

  defp typed_value("OBJECTID", value) do
    case check_oid(String.trim(value)) do
      {:ok, oid} -> {:ok, oid}
      {:error, _} -> {:error, "OBJECTID value must be dotted numbers"}
    end
  end

  defp typed_value(_type, value), do: {:ok, value}
end
