defmodule Bindocsis.ConfigNames do
  @moduledoc """
  Identifier <-> TLV type mapping for the human-readable config format.

  Every identifier is derived from the specification tables at compile
  time; there is no hand-written name list (issue #6):

  - top-level DOCSIS TLVs: `Bindocsis.DocsisSpecs` (4.0 superset)
  - top-level PacketCable MTA TLVs: `Bindocsis.MtaSpecs`
  - sub-TLVs: `Bindocsis.SubTlvSpecs`, looked up by the full parent path

  An identifier is the spec name with every non-alphanumeric character
  removed: "Network Access Control" -> `NetworkAccessControl`,
  "SW Upgrade Filename" -> `SWUpgradeFilename`, "Enable 2.0 Mode" ->
  `Enable20Mode`. Lookups are case-insensitive. Any TLV without a spec
  name is written and read as the generic `TLV<n>` form.

  Names are resolved in the DOCSIS namespace first and then the MTA
  namespace; for `:mta` files the order is reversed. Sub-TLVs of
  MTA-specific parents have no spec table in this library and always use
  the generic form.
  """

  alias Bindocsis.{DocsisSpecs, MtaSpecs, SubTlvSpecs}

  @docsis_version "4.0"
  @mta_version "2.0"

  @type file_type :: :docsis | :mta | :auto
  @type path :: [non_neg_integer()]

  @docsis_names DocsisSpecs.get_spec(@docsis_version)
                |> Map.new(fn {type, info} ->
                  {type, Regex.replace(~r/[^A-Za-z0-9]/, info.name, "")}
                end)
  @docsis_types Map.new(@docsis_names, fn {type, id} -> {String.downcase(id), type} end)

  @mta_names MtaSpecs.get_spec(@mta_version)
             |> Map.new(fn {type, info} ->
               {type, Regex.replace(~r/[^A-Za-z0-9]/, info.name, "")}
             end)
  @mta_types Map.new(@mta_names, fn {type, id} -> {String.downcase(id), type} end)

  @doc "Spec name -> identifier (`\"SW Upgrade Filename\"` -> `\"SWUpgradeFilename\"`)."
  @spec identifier(String.t()) :: String.t()
  def identifier(name) when is_binary(name), do: Regex.replace(~r/[^A-Za-z0-9]/, name, "")

  @doc "Case-insensitive lookup key for an identifier (also strips `_`, `-`, spaces)."
  @spec normalize(String.t()) :: String.t()
  def normalize(name) when is_binary(name), do: name |> identifier() |> String.downcase()

  @doc """
  Identifier for TLV `type` under `path` (`[]` = top level).
  """
  @spec name(non_neg_integer(), path(), file_type()) :: String.t()
  def name(type, [], file_type) do
    case top_level_lookup(type, file_type) do
      {:ok, id} -> id
      :error -> generic(type)
    end
  end

  def name(type, path, file_type) do
    case subtlv_spec(type, path, file_type) do
      %{name: spec_name} when is_binary(spec_name) -> identifier(spec_name)
      _ -> generic(type)
    end
  end

  @doc """
  Resolves an identifier under `path` to its TLV type.

  Accepts spec-derived identifiers (case-insensitively) and the generic
  `TLV<n>` form.
  """
  @spec type_for(String.t(), path(), file_type()) :: {:ok, 0..255} | :error
  def type_for(name, path, file_type) when is_binary(name) do
    key = normalize(name)

    with :error <- generic_type(key),
         :error <- spec_type(key, path, file_type) do
      :error
    end
  end

  @doc "Value type used to parse/format a leaf TLV (may be `{:enum, map, base}`)."
  @spec value_type(non_neg_integer(), path(), file_type()) :: atom() | tuple()
  def value_type(type, [], file_type) do
    case top_level_info(type, file_type) do
      {:ok, info} -> canonical_value_type(Map.get(info, :value_type, :binary))
      :error -> :binary
    end
  end

  def value_type(type, path, file_type) do
    case subtlv_spec(type, path, file_type) do
      %{value_type: vt} = spec ->
        base = canonical_value_type(vt)

        case Map.get(spec, :enum_values) do
          enum when is_map(enum) and map_size(enum) > 0 -> {:enum, enum, base}
          _ -> base
        end

      _ ->
        :binary
    end
  end

  @doc "True when the spec declares the TLV as a container of sub-TLVs."
  @spec compound?(non_neg_integer(), path(), file_type()) :: boolean()
  def compound?(type, [], file_type) do
    case top_level_info(type, file_type) do
      {:ok, info} ->
        Map.get(info, :subtlv_support, false) or
          Map.get(info, :value_type) in [:compound, :service_flow, :vendor]

      :error ->
        false
    end
  end

  def compound?(type, path, file_type) do
    case subtlv_spec(type, path, file_type) do
      %{value_type: vt} when vt in [:compound, :service_flow, :vendor] -> true
      %{} -> nested_context?(path ++ [type], file_type)
      _ -> false
    end
  end

  # A sub-TLV declared as plain :binary may still be a documented nested
  # encoding (e.g. 22.9 IPv4 classification, 24.35 buffer control): the
  # spec table has an explicit entry for its full path. SubTlvSpecs falls
  # back to the last path element for unknown paths, so a genuine nested
  # context is one whose table differs from that fallback.
  defp nested_context?([_ | _] = full_path, file_type) do
    last = List.last(full_path)

    with false <- mta_root?(full_path, file_type),
         {:ok, nested} <- SubTlvSpecs.get_subtlv_specs(full_path) do
      case SubTlvSpecs.get_subtlv_specs(last) do
        {:ok, ^nested} -> false
        _ -> true
      end
    else
      _ -> false
    end
  end

  defp mta_root?([root | _], file_type) do
    (file_type == :mta and Map.has_key?(@mta_names, root)) or
      (file_type != :docsis and mta_only_root?(root))
  end

  @doc "Spec description for comments, or nil."
  @spec description(non_neg_integer(), path(), file_type()) :: String.t() | nil
  def description(type, [], file_type) do
    case top_level_info(type, file_type) do
      {:ok, info} -> Map.get(info, :description)
      :error -> nil
    end
  end

  def description(type, path, file_type) do
    case subtlv_spec(type, path, file_type) do
      %{description: d} when is_binary(d) -> d
      _ -> nil
    end
  end

  @doc "All top-level identifiers the parser understands (DOCSIS then MTA)."
  @spec top_level_identifiers() :: [String.t()]
  def top_level_identifiers do
    (Map.values(@docsis_names) ++ Map.values(@mta_names)) |> Enum.uniq() |> Enum.sort()
  end

  @doc "Type -> identifier map for the DOCSIS namespace."
  @spec docsis_names() :: %{non_neg_integer() => String.t()}
  def docsis_names, do: @docsis_names

  @doc "Type -> identifier map for the MTA namespace."
  @spec mta_names() :: %{non_neg_integer() => String.t()}
  def mta_names, do: @mta_names

  @doc "Generic identifier for a TLV without a spec name."
  @spec generic(non_neg_integer()) :: String.t()
  def generic(type), do: "TLV#{type}"

  # -- private -------------------------------------------------------------

  defp generic_type("tlv" <> digits) do
    case Integer.parse(digits) do
      {n, ""} when n >= 0 and n <= 255 -> {:ok, n}
      _ -> :error
    end
  end

  defp generic_type(_), do: :error

  defp spec_type(key, [], file_type) do
    Enum.find_value(namespaces(file_type), :error, fn
      :docsis -> Map.fetch(@docsis_types, key) |> ok_or_nil()
      :mta -> Map.fetch(@mta_types, key) |> ok_or_nil()
    end)
  end

  defp spec_type(key, path, file_type) do
    path
    |> subtlv_specs(file_type)
    |> Enum.find_value(:error, fn {type, spec} ->
      if normalize(Map.get(spec, :name, "")) == key, do: {:ok, type}
    end)
  end

  defp ok_or_nil({:ok, v}), do: {:ok, v}
  defp ok_or_nil(:error), do: nil

  defp namespaces(:mta), do: [:mta, :docsis]
  defp namespaces(_), do: [:docsis, :mta]

  defp top_level_lookup(type, file_type) do
    Enum.find_value(namespaces(file_type), :error, fn
      :docsis -> Map.fetch(@docsis_names, type) |> ok_or_nil()
      :mta -> Map.fetch(@mta_names, type) |> ok_or_nil()
    end)
  end

  defp top_level_info(type, file_type) do
    Enum.find_value(namespaces(file_type), :error, fn
      :docsis ->
        case DocsisSpecs.get_tlv_info(type, @docsis_version) do
          {:ok, info} -> {:ok, info}
          _ -> nil
        end

      :mta ->
        case MtaSpecs.get_tlv_info(type, @mta_version) do
          {:ok, info} -> {:ok, info}
          _ -> nil
        end
    end)
  end

  # Sub-TLV spec table for a parent path, or %{} when the library has none.
  defp subtlv_specs([root | _] = path, file_type) do
    # In an MTA file every MTA-defined root is PacketCable content; in
    # auto/DOCSIS mode only the MTA-only types (no DOCSIS meaning) are.
    mta_parent? = file_type == :mta and Map.has_key?(@mta_names, root)

    if mta_parent? or (file_type != :docsis and mta_only_root?(root)) do
      %{}
    else
      case SubTlvSpecs.get_subtlv_specs(path) do
        {:ok, specs} when is_map(specs) -> specs
        _ -> %{}
      end
    end
  end

  defp subtlv_specs(_, _), do: %{}

  # Types that exist only in the MTA namespace (no DOCSIS meaning), so their
  # children cannot be described by the DOCSIS sub-TLV tables.
  defp mta_only_root?(root),
    do: Map.has_key?(@mta_names, root) and not Map.has_key?(@docsis_names, root)

  defp subtlv_spec(type, path, file_type) do
    Map.get(subtlv_specs(path, file_type), type)
  end

  # MtaSpecs uses a couple of legacy atoms; map them onto the ValueParser vocabulary.
  defp canonical_value_type(:raw), do: :binary
  defp canonical_value_type(:mac), do: :mac_address
  defp canonical_value_type(other), do: other
end
