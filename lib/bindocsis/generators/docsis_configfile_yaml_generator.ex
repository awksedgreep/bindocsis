defmodule Bindocsis.Generators.DocsisConfigfileYamlGenerator do
  @moduledoc """
  Writes PacketCable MTA TLVs as docsis-configfile YAML, the dialect read by
  `Bindocsis.Parsers.DocsisConfigfileYamlParser`.

  This is the reverse of that parser. Converting an MTA file to YAML and back
  must give the same bytes, so `generate/2` checks it: it converts its own
  output back to a binary and returns an error, never a lossy document, when
  the result differs from the input TLVs. Files the dialect cannot express
  include:

  - TLV order other than `254=0x01, 11/64..., 43..., 254=0xFF`. The parser
    always writes SNMP objects before vendor-specific TLVs.
  - DOCSIS TLVs (for example the CM/CMTS MIC) or any type other than
    11/43/64/254.
  - SNMP values whose BER encoding is not the one the parser writes.

  ## Example

      iex> yaml = "---\\nMtaConfigDelimiter:\\n- 1\\n- 255\\nSnmpMibObject:\\n- oid: 1.3.6.1.4.1.4491.2.2.1.1.1.7.0\\n  INTEGER: 1\\n"
      iex> {:ok, tlvs} = Bindocsis.parse(yaml, format: :docsis_configfile_yaml)
      iex> {:ok, out} = Bindocsis.Generators.DocsisConfigfileYamlGenerator.generate(tlvs)
      iex> Bindocsis.parse(out, format: :docsis_configfile_yaml) == {:ok, tlvs}
      true
  """

  import Bitwise

  alias Bindocsis.Generators.MtaBinaryGenerator
  alias Bindocsis.Parsers.DocsisConfigfileYamlParser

  @doc "Generates docsis-configfile YAML from MTA TLVs."
  @spec generate([map()], keyword()) :: {:ok, String.t()} | {:error, String.t()}
  def generate(tlvs, _opts \\ []) when is_list(tlvs) do
    with {:ok, sections} <- split(tlvs),
         {:ok, yaml} <- render(sections),
         :ok <- verify(tlvs, yaml) do
      {:ok, yaml}
    end
  end

  # -- structure ---------------------------------------------------------

  defp split(tlvs) do
    {delims, body} = Enum.split_with(tlvs, &(&1.type == 254))

    cond do
      Enum.any?(body, &(&1.type not in [11, 43, 64])) ->
        types = body |> Enum.map(& &1.type) |> Enum.reject(&(&1 in [11, 43, 64])) |> Enum.uniq()

        {:error,
         "docsis-configfile YAML cannot express TLV type(s) #{Enum.join(types, ", ")} " <>
           "(only 254, 11, 64 and 43)"}

      true ->
        {snmp, vendor} = Enum.split_with(body, &(&1.type in [11, 64]))

        with {:ok, snmp_entries} <- map_ok(snmp, &snmp_entry/1),
             {:ok, vendor_entries} <- map_ok(vendor, &vendor_entry/1),
             {:ok, delimiters} <- map_ok(delims, &delimiter/1) do
          {:ok, %{delimiters: delimiters, snmp: snmp_entries, vendor: vendor_entries}}
        end
    end
  end

  defp delimiter(%{value: <<v>>}), do: {:ok, v}
  defp delimiter(_), do: {:error, "TLV 254 must carry one byte"}

  defp vendor_entry(%{value: <<8, 3, oui::binary-size(3), options::binary>>}) do
    with {:ok, opts} <- vendor_options(options, []) do
      {:ok, %{id: "0x" <> Base.encode16(oui, case: :lower), options: opts}}
    end
  end

  defp vendor_entry(_),
    do: {:error, "TLV 43 must start with a vendor ID sub-TLV (8, length 3)"}

  defp vendor_options(<<>>, acc), do: {:ok, Enum.reverse(acc)}

  defp vendor_options(<<type, len, value::binary-size(len), rest::binary>>, acc),
    do: vendor_options(rest, ["0x" <> Base.encode16(value, case: :lower), type | acc])

  defp vendor_options(_, _), do: {:error, "TLV 43 sub-TLVs do not parse"}

  # -- SNMP variable binding (BER) -----------------------------------------

  defp snmp_entry(%{value: value}) do
    with {:ok, <<0x30>>, seq, <<>>} <- ber(value),
         {:ok, <<0x06>>, oid_bytes, rest} <- ber(seq),
         {:ok, <<tag>>, val, <<>>} <- ber(rest),
         {:ok, oid} <- decode_oid(oid_bytes),
         {:ok, key, yaml_value} <- snmp_value(tag, val) do
      {:ok, {key, yaml_value, oid}}
    else
      {:error, _} = e -> e
      _ -> {:error, "TLV 11/64 value is not an SNMP variable binding"}
    end
  end

  defp ber(<<tag, 0::1, len::7, rest::binary>>) when byte_size(rest) >= len,
    do: split_value(<<tag>>, len, rest)

  defp ber(<<tag, 1::1, n::7, rest::binary>>) when n in 1..2 and byte_size(rest) >= n do
    <<len::size(^n * 8), rest2::binary>> = rest
    if byte_size(rest2) >= len, do: split_value(<<tag>>, len, rest2), else: :error
  end

  defp ber(_), do: :error

  defp split_value(tag, len, data) do
    <<v::binary-size(^len), rest::binary>> = data
    {:ok, tag, v, rest}
  end

  defp snmp_value(0x02, v), do: {:ok, "INTEGER", signed(v)}
  defp snmp_value(0x04, v), do: {:ok, "STRING", string(v)}
  defp snmp_value(0x05, <<>>), do: {:ok, "NULLOBJ", ""}
  defp snmp_value(0x06, v), do: with({:ok, oid} <- decode_oid(v), do: {:ok, "OBJECTID", oid})
  defp snmp_value(0x40, <<a, b, c, d>>), do: {:ok, "IPADDRESS", "#{a}.#{b}.#{c}.#{d}"}
  defp snmp_value(0x41, v), do: {:ok, "COUNTER", :binary.decode_unsigned(v)}
  defp snmp_value(0x42, v), do: {:ok, "UNSIGNED", :binary.decode_unsigned(v)}
  defp snmp_value(0x43, v), do: {:ok, "TIMETICKS", :binary.decode_unsigned(v)}
  defp snmp_value(0x44, v), do: {:ok, "OPAQUE", :binary.decode_unsigned(v)}
  defp snmp_value(0x46, v), do: {:ok, "COUNTER64", signed(v)}

  defp snmp_value(tag, _),
    do: {:error, "SNMP value type 0x#{Integer.to_string(tag, 16)} has no docsis-configfile name"}

  defp signed(<<>>), do: 0

  defp signed(<<first, _::binary>> = v) do
    n = :binary.decode_unsigned(v)
    if first >= 0x80, do: n - (1 <<< (8 * byte_size(v))), else: n
  end

  # Printable text stays text; anything else, or text the parser would read
  # as hex, is written as 0x-hex.
  defp string(v) do
    printable? =
      String.valid?(v) and String.printable?(v) and not String.contains?(v, ["\n", "\r", "\t"])

    if printable? and not String.match?(v, ~r/^0[xX]/),
      do: {:text, v},
      else: {:hex, "0x" <> Base.encode16(v, case: :lower)}
  end

  defp decode_oid(<<first, rest::binary>>) do
    {ids, partial} =
      for(<<b <- rest>>, do: b)
      |> Enum.reduce({[], 0}, fn b, {ids, cur} ->
        cur = cur * 128 + (b &&& 0x7F)
        if b >= 0x80, do: {ids, cur}, else: {[cur | ids], 0}
      end)

    if partial != 0,
      do: {:error, "truncated OID"},
      else: {:ok, Enum.join([div(first, 40), rem(first, 40) | Enum.reverse(ids)], ".")}
  end

  defp decode_oid(<<>>), do: {:error, "empty OID"}

  # -- rendering -----------------------------------------------------------

  defp render(%{delimiters: delimiters, snmp: snmp, vendor: vendor}) do
    lines =
      ["---"] ++
        section("MtaConfigDelimiter", Enum.map(delimiters, &"- #{&1}")) ++
        render_vendor(vendor) ++
        section("SnmpMibObject", Enum.flat_map(snmp, &render_snmp/1))

    {:ok, Enum.join(lines, "\n") <> "\n"}
  end

  defp section(_key, []), do: []
  defp section(key, lines), do: ["#{key}:" | lines]

  defp render_vendor([]), do: []

  defp render_vendor([one]),
    do: ["VendorSpecific:", "  id: #{quote_s(one.id)}" | options_lines(one)]

  defp render_vendor(many) do
    ["VendorSpecific:"] ++
      Enum.flat_map(many, fn v -> ["- id: #{quote_s(v.id)}" | options_lines(v)] end)
  end

  # A vendor TLV with only its vendor ID still needs a list for the parser.
  defp options_lines(%{options: []}), do: ["  options: []"]
  defp options_lines(v), do: ["  options:" | vendor_lines(v, "  ")]

  defp vendor_lines(%{options: options}, indent) do
    Enum.map(options, fn
      o when is_integer(o) -> "#{indent}- #{o}"
      o -> "#{indent}- #{quote_s(o)}"
    end)
  end

  defp render_snmp({key, value, oid}),
    do: ["- #{key}: #{scalar(value)}", "  oid: #{oid}"]

  defp scalar({:text, s}), do: quote_s(s)
  defp scalar({:hex, s}), do: quote_s(s)
  defp scalar(n) when is_integer(n), do: Integer.to_string(n)
  defp scalar(""), do: "''"
  defp scalar(s) when is_binary(s), do: quote_s(s)

  # YAML single-quoted scalar: only ' needs escaping (as '').
  defp quote_s(s), do: "'" <> String.replace(s, "'", "''") <> "'"

  # -- self-check ----------------------------------------------------------

  defp verify(tlvs, yaml) do
    with {:ok, expected} <- MtaBinaryGenerator.generate(tlvs, validate: false),
         {:ok, reparsed} <- DocsisConfigfileYamlParser.parse(yaml),
         {:ok, actual} <- MtaBinaryGenerator.generate(reparsed, validate: false) do
      if actual == expected,
        do: :ok,
        else:
          {:error,
           "docsis-configfile YAML cannot reproduce this file byte for byte " <>
             "(TLV order or encoding differs from what the YAML dialect writes)"}
    else
      {:error, reason} -> {:error, "docsis-configfile YAML self-check failed: #{reason}"}
    end
  end

  defp map_ok(list, fun) do
    Enum.reduce_while(list, {:ok, []}, fn item, {:ok, acc} ->
      case fun.(item) do
        {:ok, v} -> {:cont, {:ok, [v | acc]}}
        {:error, _} = e -> {:halt, e}
      end
    end)
    |> case do
      {:ok, acc} -> {:ok, Enum.reverse(acc)}
      e -> e
    end
  end
end
