defmodule Bindocsis.Tui.Format do
  @moduledoc """
  Pure view-model helpers for the `bindocsis tui` browser.

  Converts `Bindocsis.Tui.State` into plain strings/lines; the runtime
  (`Bindocsis.Tui.App`) wraps them in ExRatatui widgets. Every function
  here is side-effect free and safe to unit test without a terminal.
  """

  alias Bindocsis.Tui.State

  @hex_bytes_per_row 16
  @hex_max_rows 64

  @doc "One-line label for a tree row (indent + expand marker + TLV summary)."
  @spec tree_label(State.row()) :: String.t()
  def tree_label(%{tlv: tlv, depth: depth, has_children: has_children, expanded: expanded}) do
    marker =
      cond do
        has_children and expanded -> "▾ "
        has_children -> "▸ "
        true -> "  "
      end

    indent = String.duplicate("  ", depth)
    name = Map.get(tlv, :name, "Unknown") |> to_string() |> truncate(28)
    "#{indent}#{marker}T#{tlv.type} #{name} (#{tlv.length}B)"
  end

  @doc "Detail pane lines for a TLV (decoded value, spec reference)."
  @spec detail_lines(map() | nil) :: [String.t()]
  def detail_lines(nil), do: ["No TLV selected"]

  def detail_lines(tlv) do
    value_line =
      case Map.get(tlv, :subtlvs, []) do
        subtlvs when is_list(subtlvs) and length(subtlvs) > 0 ->
          "Value: <compound: #{length(subtlvs)} sub-TLVs>"

        _ ->
          "Value: #{display_value(Map.get(tlv, :formatted_value))}"
      end

    [
      "#{Map.get(tlv, :name, "Unknown TLV")} (Type #{tlv.type})",
      "Length: #{tlv.length} byte(s)",
      "Value type: #{Map.get(tlv, :value_type, :unknown)}",
      value_line,
      "Description: #{Map.get(tlv, :description, "—")}",
      "Category: #{Map.get(tlv, :docsis_category, "—")}",
      "Introduced: #{Map.get(tlv, :introduced_version, "—")}"
    ]
  end

  @doc "Hex dump lines for the selected TLV's value bytes."
  @spec hex_lines(map() | nil) :: [String.t()]
  def hex_lines(nil), do: ["No TLV selected"]
  def hex_lines(%{value: value}) when is_binary(value), do: hex_dump(value, 0)
  def hex_lines(%{raw_value: raw}) when is_binary(raw), do: hex_dump(raw, 0)
  def hex_lines(_), do: ["<non-binary value>"]

  @doc """
  Initial text for the edit input: the human-editable `formatted_value`.
  Falls back to empty string for compound parents (which are not editable).
  """
  @spec edit_text(map() | nil) :: String.t()
  def edit_text(nil), do: ""

  def edit_text(tlv) do
    case Map.get(tlv, :formatted_value) do
      value when is_binary(value) -> value
      _ -> ""
    end
  end

  @doc "One-line edit popup title for a TLV."
  @spec edit_title(map() | nil) :: String.t()
  def edit_title(nil), do: " Edit value "
  def edit_title(tlv), do: " Edit T#{tlv.type} #{Map.get(tlv, :name, "")} "
  @doc "Header bar text for the current state."
  @spec header_text(State.t()) :: String.t()
  def header_text(state) do
    file = state.path || "<no file>"
    dirty = if state.dirty, do: " ●modified", else: ""
    validity = if State.valid?(state), do: "VALID", else: "INVALID (#{State.issue_count(state)})"

    "#{file} — #{length(state.tlvs)} TLVs (#{length(state.rows)} shown) — #{validity}#{dirty}"
  end

  @doc "Footer hint text for the current state."
  @spec footer_text(State.t()) :: String.t()
  def footer_text(%{search_active: true}), do: "Type to filter • Enter: keep • Esc: clear"

  def footer_text(%{search_query: q} = state) when q != "" do
    "Filter: #{inspect(q)} • " <> footer_hints(state)
  end

  def footer_text(state), do: footer_hints(state)

  defp footer_hints(%{focus: :tree}),
    do:
      "j/k: move • Enter: expand • e: edit • s: save • X: export • /: search • v: issues • ?: help • q: quit"

  defp footer_hints(%{focus: focus}),
    do: "#{focus}: j/k scroll • Tab: pane • Esc: tree • ?: help • q: quit"

  @doc "Validation overlay lines (violations then warnings, capped)."
  @spec validation_lines(State.t(), pos_integer()) :: [String.t()]
  def validation_lines(%{validation: nil}, _max), do: ["File was not validated"]

  def validation_lines(%{validation: validation}, max) do
    violations =
      validation |> Map.get(:violations, []) |> Enum.map(&"[#{&1.severity}] #{&1.description}")

    warnings =
      validation
      |> Map.get(:warnings, [])
      |> Enum.map(&"[warn] #{Map.get(&1, :description, inspect(&1))}")

    lines = violations ++ warnings

    lines =
      if lines == [],
        do: ["No issues — configuration is valid (#{validation.docsis_version})"],
        else: lines

    Enum.take(lines, max) ++
      if length(lines) > max, do: ["… #{length(lines) - max} more"], else: []
  end

  @doc "Static help overlay lines."
  @spec help_lines() :: [String.t()]
  def help_lines do
    [
      "bindocsis tui — key bindings",
      "",
      "  j / k, Up / Down  move selection",
      "  Enter             expand / collapse compound TLV",
      "  Tab               cycle focus: tree → detail → hex",
      "  j / k (detail/hex focused)  scroll pane",
      "  Esc               back to tree / clear search",
      "  /                 search by type number or name",
      "  e                 edit selected value",
      "  s                 save to file (recomputes CM MIC)",
      "  X                 export (binary / json / yaml / config)",
      "  v                 validation issues overlay",
      "  ?                 this help",
      "  q                 quit",
      "",
      "Only leaf TLVs are editable; compound TLVs are structural —",
      "expand them and edit a sub-TLV. CM MIC (TLV 6) is recomputed",
      "on save; CMTS MIC (TLV 7) needs BINDOCSIS_SHARED_SECRET."
    ]
  end

  @doc "Export format options in menu order."
  @spec export_formats() :: [{atom(), String.t()}]
  def export_formats,
    do: [binary: "Binary (.cm)", json: "JSON", yaml: "YAML", config: "Config text"]

  @doc "Default export path for `format` next to the loaded file."
  @spec export_path(String.t() | nil, atom()) :: String.t()
  def export_path(nil, format), do: "export.#{format}"

  def export_path(path, format) do
    ext = if format == :binary, do: "cm", else: Atom.to_string(format)
    base = Path.rootname(path)
    if base == path, do: "#{path}.#{ext}", else: "#{base}.#{ext}"
  end

  # -- internals --------------------------------------------------------

  defp display_value(nil), do: "—"
  defp display_value(value) when is_binary(value), do: truncate(value, 60)
  defp display_value(value), do: value |> inspect() |> truncate(60)

  defp truncate(str, max) when is_binary(str) do
    if String.length(str) > max, do: String.slice(str, 0, max - 1) <> "…", else: str
  end

  defp hex_dump(binary, _offset) do
    total_rows = div(byte_size(binary) + @hex_bytes_per_row - 1, @hex_bytes_per_row)

    rows =
      binary
      |> :binary.bin_to_list()
      |> Enum.chunk_every(@hex_bytes_per_row)
      |> Enum.with_index()
      |> Enum.take(@hex_max_rows)
      |> Enum.map(fn {chunk, idx} ->
        offset = Integer.to_string(idx * @hex_bytes_per_row, 16) |> String.pad_leading(4, "0")

        hex =
          chunk
          |> Enum.map(&(Integer.to_string(&1, 16) |> String.pad_leading(2, "0")))
          |> Enum.join(" ")

        hex = String.pad_trailing(hex, @hex_bytes_per_row * 3 - 1)
        ascii = chunk |> Enum.map(&printable/1) |> Enum.join()
        "#{offset}  #{hex}  |#{ascii}|"
      end)

    case {total_rows, rows} do
      {0, _} ->
        ["<empty value>"]

      {n, rows} when n > @hex_max_rows ->
        rows ++ ["… #{n - @hex_max_rows} more rows (#{byte_size(binary)} bytes total)"]

      {_, rows} ->
        rows
    end
  end

  defp printable(byte) when byte >= 32 and byte < 127, do: <<byte>>
  defp printable(_), do: "."
end
