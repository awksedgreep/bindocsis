defmodule Bindocsis.Parsers.ConfigParser do
  @moduledoc """
  Parses the human-readable config format into TLVs.

  ## Syntax

      # Comments start with # or // (whole line)
      NetworkAccessControl enabled          # a leaf: <Name> <value>
      DownstreamFrequency 591 MHz
      SWUpgradeFilename "modem-1.2.bin"     # strings may be quoted
      UpstreamServiceFlow {                 # a compound: <Name> {
          ServiceFlowReference 1            #   sub-TLV names come from the
          QoSParameterSetType 7             #   spec table for that parent
          ServiceFlowErrorEncoding { }      #   nested blocks, empty allowed
      }
      TLV254 AA BB CC                       # any type as TLV<n>; raw hex value
      VendorSpecific 0x0010950102           # 0x-prefixed hex is raw bytes

  Names are resolved by `Bindocsis.ConfigNames` from the specification
  tables (issue #6); they are case-insensitive and `_`/`-` are ignored.
  Values are parsed with `Bindocsis.ValueParser` according to the TLV's
  spec value type, so the same text forms accepted in JSON/YAML
  `formatted_value` fields work here. Binary-typed TLVs take hex bytes
  (`AA BB`, `AABB`, `AA:BB`, `0xAABB`) or a quoted string.

  Any malformed line fails the whole parse with its line number; nothing is
  silently skipped. Compound values are encoded with the shared
  `Bindocsis.TlvLength` codec.

  ## Options

  - `:file_type` - `:docsis`, `:mta` or `:auto` (default). Controls which
    namespace wins when a name exists in both.
  """

  alias Bindocsis.{ConfigNames, TlvLength, ValueParser}

  @type tlv :: %{type: 0..255, length: non_neg_integer(), value: binary()}

  @string_types [:string, :string_null]
  @binary_types [:binary, :hex_string, :asn1_der, :vendor, :marker, :compound, :service_flow]

  @doc """
  Parses a config string into TLVs.

  ## Examples

      iex> Bindocsis.Parsers.ConfigParser.parse("NetworkAccessControl enabled")
      {:ok, [%{type: 3, length: 1, value: <<1>>}]}
  """
  @spec parse(String.t(), keyword()) :: {:ok, [tlv()]} | {:error, String.t()}
  def parse(config_string, opts \\ []) when is_binary(config_string) do
    file_type = Keyword.get(opts, :file_type, :auto)

    lines =
      config_string
      |> String.split(~r/\r?\n/)
      |> Enum.with_index(1)
      |> Enum.map(fn {line, n} -> {String.trim(line), n} end)
      |> Enum.reject(fn {line, _} -> comment_or_blank?(line) end)

    case parse_block(lines, [], file_type, []) do
      {:ok, tlvs, [], :eof} ->
        {:ok, tlvs}

      {:ok, _tlvs, _rest, {:closed, n}} ->
        {:error, "Line #{n}: unexpected '}' with no open block"}

      {:error, _} = error ->
        error
    end
  end

  @doc """
  Parses a config file into TLVs.
  """
  @spec parse_file(String.t(), keyword()) :: {:ok, [tlv()]} | {:error, String.t()}
  def parse_file(path, opts \\ []) when is_binary(path) do
    case File.read(path) do
      {:ok, content} -> parse(content, opts)
      {:error, reason} -> {:error, "File read error: #{reason}"}
    end
  end

  @doc """
  Resolves a top-level identifier to its TLV type.

      iex> Bindocsis.Parsers.ConfigParser.get_tlv_type("NetworkAccessControl")
      {:ok, 3}
      iex> Bindocsis.Parsers.ConfigParser.get_tlv_type("network_access_control")
      {:ok, 3}
      iex> Bindocsis.Parsers.ConfigParser.get_tlv_type("TLV254")
      {:ok, 254}
      iex> Bindocsis.Parsers.ConfigParser.get_tlv_type("NoSuchThing")
      {:error, :not_found}
  """
  @spec get_tlv_type(String.t()) :: {:ok, 0..255} | {:error, :not_found}
  def get_tlv_type(name) when is_binary(name) do
    case ConfigNames.type_for(name, [], :auto) do
      {:ok, type} -> {:ok, type}
      :error -> {:error, :not_found}
    end
  end

  @doc "All top-level identifiers (DOCSIS and MTA), sorted."
  @spec supported_tlv_names() :: [String.t()]
  def supported_tlv_names, do: ConfigNames.top_level_identifiers()

  @doc """
  Validates parsed TLVs or checks that a config string has at least one
  statement.
  """
  def validate_structure(config) when is_list(config) do
    if Enum.all?(config, &valid_tlv?/1),
      do: {:ok, config},
      else: {:error, "Invalid TLV structure found"}
  end

  def validate_structure(config) when is_binary(config) do
    statements =
      config
      |> String.split(~r/\r?\n/)
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&comment_or_blank?/1)

    if statements == [],
      do: {:error, "Config file contains no valid TLV declarations"},
      else: :ok
  end

  # -- block parser ---------------------------------------------------------

  # Returns {:ok, tlvs, remaining_lines, {:closed, line} | :eof} or {:error, msg}.
  defp parse_block([], _path, _ft, acc), do: {:ok, Enum.reverse(acc), [], :eof}

  defp parse_block([{"}", n} | rest], _path, _ft, acc),
    do: {:ok, Enum.reverse(acc), rest, {:closed, n}}

  defp parse_block([{line, n} | rest], path, ft, acc) do
    case classify(line) do
      {:open, name} ->
        with {:ok, type} <- resolve(name, path, ft, n),
             {:ok, children, rest2, {:closed, _}} <- parse_block(rest, path ++ [type], ft, []) do
          parse_block(rest2, path, ft, [compound(type, children) | acc])
        else
          {:ok, _children, [], :eof} ->
            {:error, "Line #{n}: unclosed block '#{name} {' (reached end of file)"}

          {:error, _} = error ->
            error
        end

      {:inline, name, inner} ->
        with {:ok, type} <- resolve(name, path, ft, n),
             {:ok, children} <- parse_inline(inner, path ++ [type], ft, n) do
          parse_block(rest, path, ft, [compound(type, children) | acc])
        end

      {:leaf, name, text} ->
        with {:ok, type} <- resolve(name, path, ft, n),
             {:ok, value} <- convert_leaf(text, ConfigNames.value_type(type, path, ft), name, n) do
          parse_block(rest, path, ft, [
            %{type: type, length: byte_size(value), value: value} | acc
          ])
        end

      {:error, reason} ->
        {:error, "Line #{n}: #{reason}"}
    end
  end

  # Single-line block: `Name { }` or `Name { Sub value }` (one statement, no nesting)
  defp parse_inline("", _path, _ft, _n), do: {:ok, []}

  defp parse_inline(inner, path, ft, n) do
    case classify(inner) do
      {:leaf, name, text} ->
        with {:ok, type} <- resolve(name, path, ft, n),
             {:ok, value} <- convert_leaf(text, ConfigNames.value_type(type, path, ft), name, n) do
          {:ok, [%{type: type, length: byte_size(value), value: value}]}
        end

      _ ->
        {:error, "Line #{n}: a single-line block may hold at most one '<Name> <value>' statement"}
    end
  end

  defp classify(line) do
    cond do
      String.ends_with?(line, "{") ->
        name = line |> String.trim_trailing("{") |> String.trim()

        if single_token?(name),
          do: {:open, name},
          else: {:error, "invalid block header '#{line}'"}

      String.contains?(line, "{") and String.ends_with?(line, "}") ->
        [name, inner] = String.split(line, "{", parts: 2)
        name = String.trim(name)
        inner = inner |> String.trim_trailing("}") |> String.trim()

        if single_token?(name),
          do: {:inline, name, inner},
          else: {:error, "invalid block header '#{line}'"}

      true ->
        case String.split(line, ~r/\s+/, parts: 2) do
          [name] -> {:error, "Missing value for TLV: #{name}"}
          [name, text] -> {:leaf, name, String.trim(text)}
        end
    end
  end

  defp single_token?(name), do: name != "" and not String.contains?(name, [" ", "\t"])

  defp resolve(name, path, ft, n) do
    case ConfigNames.type_for(name, path, ft) do
      {:ok, type} ->
        {:ok, type}

      :error ->
        where = if path == [], do: "", else: " inside #{Enum.map_join(path, ".", &to_string/1)}"
        {:error, "Line #{n}: Unknown TLV name: #{name}#{where} (use TLV<n> for unnamed types)"}
    end
  end

  defp compound(type, children) do
    value =
      children
      |> Enum.map(fn %{type: t, length: l, value: v} -> [<<t>>, TlvLength.encode(l), v] end)
      |> IO.iodata_to_binary()

    %{type: type, length: byte_size(value), value: value}
  end

  # -- leaf values ----------------------------------------------------------

  defp convert_leaf(text, value_type, name, n) do
    case do_convert(text, value_type) do
      {:ok, value} when is_binary(value) -> {:ok, value}
      {:error, reason} -> {:error, "Line #{n}: Invalid value '#{text}' for #{name}: #{reason}"}
    end
  end

  defp do_convert(~s(""), _vt), do: {:ok, <<>>}
  defp do_convert("''", _vt), do: {:ok, <<>>}

  defp do_convert(<<q, _::binary>> = text, vt) when q in [?", ?'] do
    with {:ok, inner} <- unquote_string(text) do
      cond do
        string_type?(vt) -> ValueParser.parse_value(base_type(vt), inner, [])
        binary_type?(vt) -> {:ok, inner}
        true -> ValueParser.parse_value(vt, inner, [])
      end
    end
  end

  defp do_convert("0x" <> hex, _vt), do: decode_hex(hex)
  defp do_convert("0X" <> hex, _vt), do: decode_hex(hex)

  defp do_convert(text, vt) do
    cond do
      string_type?(vt) ->
        ValueParser.parse_value(base_type(vt), text, [])

      binary_type?(vt) ->
        case decode_hex(text) do
          {:ok, bytes} -> {:ok, bytes}
          {:error, _} -> {:error, "expected hex bytes (AA BB CC / 0xAABBCC) or a quoted string"}
        end

      true ->
        ValueParser.parse_value(vt, text, [])
    end
  end

  defp string_type?({:enum, _, _}), do: false
  defp string_type?(vt), do: vt in @string_types
  defp binary_type?({:enum, _, _}), do: false
  defp binary_type?(vt), do: vt in @binary_types
  defp base_type({:enum, _, base}), do: base
  defp base_type(vt), do: vt

  defp unquote_string(<<q, rest::binary>>) when q in [?", ?'] do
    if String.ends_with?(rest, <<q>>) and byte_size(rest) >= 1 do
      inner = binary_part(rest, 0, byte_size(rest) - 1)

      {:ok,
       inner
       |> String.replace("\\\"", "\"")
       |> String.replace("\\'", "'")
       |> String.replace("\\\\", "\\")}
    else
      {:error, "unterminated quoted string"}
    end
  end

  # Accepts "AA BB", "AABB", "AA:BB", "aa-bb"
  defp decode_hex(text) do
    clean = String.replace(text, ~r/[\s:\-]/, "")

    cond do
      clean == "" ->
        {:error, "empty hex value"}

      rem(String.length(clean), 2) != 0 ->
        {:error, "hex value must have an even number of digits"}

      not Regex.match?(~r/^[0-9A-Fa-f]+$/, clean) ->
        {:error, "not a hex value"}

      true ->
        {:ok, Base.decode16!(clean, case: :mixed)}
    end
  end

  defp comment_or_blank?(line) do
    line == "" or String.starts_with?(line, "#") or String.starts_with?(line, "//")
  end

  defp valid_tlv?(%{type: type, length: length, value: value})
       when is_integer(type) and is_integer(length) and is_binary(value) do
    type >= 0 and type <= 255 and length >= 0 and byte_size(value) == length
  end

  defp valid_tlv?(_), do: false
end
