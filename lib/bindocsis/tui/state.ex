defmodule Bindocsis.Tui.State do
  @moduledoc """
  Pure state container and transitions for the `bindocsis tui` browser.

  All functions here are side-effect free (apart from creating the
  search `TextInput` handle, which requires the ExRatatui NIF to be
  loaded — always true in dev/test/release). The runtime layer
  (`Bindocsis.Tui.App`) translates terminal events into these
  transitions; see `Bindocsis.Tui.Format` for the pure view model.
  """

  @type row :: %{
          id: String.t(),
          tlv: map(),
          depth: non_neg_integer(),
          has_children: boolean(),
          expanded: boolean()
        }

  @type t :: %{
          path: String.t() | nil,
          file_size: non_neg_integer(),
          tlvs: [map()],
          raw_binary: binary(),
          validation: map() | nil,
          rows: [row()],
          selected: non_neg_integer(),
          expanded: MapSet.t(String.t()),
          focus: :tree | :detail | :hex,
          detail_scroll: non_neg_integer(),
          hex_scroll: non_neg_integer(),
          search_active: boolean(),
          search_input: term() | nil,
          search_query: String.t(),
          show_help: boolean(),
          show_validation: boolean(),
          status_msg: String.t() | nil,
          editing: nil | %{row_id: String.t(), input: term(), error: String.t() | nil},
          dirty: boolean(),
          pending_quit: boolean(),
          exporting: nil | %{selected: non_neg_integer()},
          shared_secret: binary() | nil,
          docsis_version: String.t()
        }

  @doc """
  Builds initial state from a loaded file. `tlvs` must be enriched
  (see `Bindocsis.TlvEnricher`); `validation` is the
  `Bindocsis.ConfigValidator` result (or `nil` when skipped).
  """
  @spec load(%{
          path: String.t() | nil,
          file_size: non_neg_integer(),
          tlvs: [map()],
          raw_binary: binary(),
          validation: map() | nil
        }) :: t()
  def load(%{path: path, file_size: file_size, tlvs: tlvs, raw_binary: raw_binary} = args) do
    expanded = expand_all_ids(tlvs)

    %{
      path: path,
      file_size: file_size,
      tlvs: tlvs,
      raw_binary: raw_binary,
      validation: Map.get(args, :validation),
      rows: flatten(tlvs, expanded),
      selected: 0,
      expanded: expanded,
      focus: :tree,
      detail_scroll: 0,
      hex_scroll: 0,
      search_active: false,
      search_input: nil,
      search_query: "",
      show_help: false,
      show_validation: false,
      status_msg: nil,
      editing: nil,
      dirty: false,
      pending_quit: false,
      exporting: nil,
      shared_secret: Map.get(args, :shared_secret),
      docsis_version: Map.get(args, :docsis_version, "3.1")
    }
  end

  @doc "Currently selected row (or `nil` when the list is empty)."
  @spec selected_row(t()) :: row() | nil
  def selected_row(%{rows: rows, selected: selected}), do: Enum.at(rows, selected)

  @doc "Moves tree selection by `delta`, clamped to the visible rows."
  @spec move(t(), integer()) :: t()
  def move(%{rows: []} = state, _delta), do: state

  def move(%{rows: rows, selected: selected} = state, delta) do
    new_selected = max(0, min(length(rows) - 1, selected + delta))
    %{state | selected: new_selected, detail_scroll: 0, hex_scroll: 0, status_msg: nil}
  end

  @doc "Expands/collapses the selected row when it has children."
  @spec toggle(t()) :: t()
  def toggle(%{rows: []} = state), do: state

  def toggle(state) do
    case selected_row(state) do
      %{has_children: false} ->
        %{state | status_msg: "Leaf TLV — nothing to expand"}

      %{id: id} ->
        expanded =
          if MapSet.member?(state.expanded, id),
            do: MapSet.delete(state.expanded, id),
            else: MapSet.put(state.expanded, id)

        rows = visible_rows(%{state | expanded: expanded})
        # Keep selection on the toggled row when still visible.
        selected =
          case Enum.find_index(rows, &(&1.id == id)) do
            nil -> min(state.selected, max(0, length(rows) - 1))
            idx -> idx
          end

        %{state | expanded: expanded, rows: rows, selected: selected, status_msg: nil}

      nil ->
        state
    end
  end

  @doc "Cycles keyboard focus across tree/detail/hex panes."
  @spec cycle_focus(t()) :: t()
  def cycle_focus(%{focus: :tree} = state), do: %{state | focus: :detail}
  def cycle_focus(%{focus: :detail} = state), do: %{state | focus: :hex}
  def cycle_focus(%{focus: :hex} = state), do: %{state | focus: :tree}

  @doc "Scrolls the focused detail/hex pane (no-op when tree is focused)."
  @spec scroll_focused(t(), integer()) :: t()
  def scroll_focused(%{focus: :detail, detail_scroll: s} = state, delta),
    do: %{state | detail_scroll: max(0, s + delta)}

  def scroll_focused(%{focus: :hex, hex_scroll: s} = state, delta),
    do: %{state | hex_scroll: max(0, s + delta)}

  def scroll_focused(state, _delta), do: state

  @doc "Enters search mode (creates the text input handle)."
  @spec start_search(t()) :: t()
  def start_search(state) do
    state = %{
      state
      | search_active: true,
        search_input: ExRatatui.text_input_new(),
        search_query: ""
    }

    %{state | rows: visible_rows(state), selected: 0, status_msg: nil}
  end

  @doc "Applies `query` to the visible rows (search-as-you-type)."
  @spec apply_search(t(), String.t()) :: t()
  def apply_search(%{search_active: false} = state, _query), do: state

  def apply_search(state, query) do
    state = %{state | search_query: query}
    %{state | rows: visible_rows(state), selected: 0}
  end

  @doc """
  Leaves search mode. With `clear_query` (default) the filter is dropped
  and expansion rows restored; otherwise the filtered rows stay visible
  (Enter-to-keep) and can be refined with `/` or cleared with `Esc`.
  """
  @spec stop_search(t(), boolean()) :: t()
  def stop_search(state, clear_query \\ true)

  def stop_search(state, true) do
    state = %{state | search_active: false, search_input: nil, search_query: ""}

    %{state | rows: visible_rows(state), selected: 0, status_msg: nil}
  end

  def stop_search(state, false) do
    %{state | search_active: false, search_input: nil, selected: 0, status_msg: nil}
  end

  @doc "Toggles the help overlay."
  @spec toggle_help(t()) :: t()
  def toggle_help(state), do: %{state | show_help: !state.show_help}

  @doc "Toggles the validation overlay."
  @spec toggle_validation(t()) :: t()
  def toggle_validation(state), do: %{state | show_validation: !state.show_validation}

  @doc "Validation issue count (violations + warnings), 0 when not validated."
  @spec issue_count(t()) :: non_neg_integer()
  def issue_count(%{validation: nil}), do: 0

  def issue_count(%{validation: validation}) do
    length(Map.get(validation, :violations, [])) + length(Map.get(validation, :warnings, []))
  end

  @doc "True when the loaded file passed validation (or was not validated)."
  @spec valid?(t()) :: boolean()
  def valid?(%{validation: nil}), do: true
  def valid?(%{validation: validation}), do: Map.get(validation, :is_valid, false) != false

  @doc """
  Begins editing the selected row. Only leaf TLVs (no subtlvs) carry an
  editable `formatted_value` — parents are structural per the
  `formatted_value` contract. Prefills the input with `initial_text`.

  Returns `{:ok, state}` or `{:error, reason}` (state unchanged).
  """
  @spec start_edit(t(), String.t()) :: {:ok, t()} | {:error, String.t()}
  def start_edit(state, initial_text) do
    case selected_row(state) do
      %{has_children: true} ->
        {:error, "Compound TLV — expand it and edit a sub-TLV"}

      %{id: id} ->
        input = ExRatatui.text_input_new()
        :ok = ExRatatui.text_input_set_value(input, initial_text)
        {:ok, %{state | editing: %{row_id: id, input: input, error: nil}}}

      nil ->
        {:error, "Nothing selected"}
    end
  end

  @doc "Cancels the in-progress edit, discarding input."
  @spec cancel_edit(t()) :: t()
  def cancel_edit(state), do: %{state | editing: nil}

  @doc "Records a commit failure to display inside the edit popup."
  @spec set_edit_error(t(), String.t()) :: t()
  def set_edit_error(%{editing: nil} = state, _reason), do: state

  def set_edit_error(%{editing: editing} = state, reason),
    do: %{state | editing: %{editing | error: reason}}

  @doc """
  Commits `new_text` as the selected row's value.

  Parses the human representation with `ValueParser` (the inverse of the
  `formatted_value` enrichment), splices the raw bytes into the tree by
  row id, then unenriches/re-enriches the whole config so compound
  parents re-encode from their children. Marks the state dirty.

  Returns `{:ok, state}` or `{:error, reason}` (edit stays open).
  """
  @spec commit_edit(t(), String.t()) :: {:ok, t()} | {:error, String.t()}
  def commit_edit(%{editing: nil} = state, _text), do: {:ok, state}

  def commit_edit(%{editing: %{row_id: id}} = state, new_text) do
    row = Enum.find(state.rows, &(&1.id == id))

    cond do
      is_nil(row) ->
        {:error, "Selected row is gone"}

      row.has_children ->
        {:error, "Compound TLV — expand it and edit a sub-TLV"}

      true ->
        apply_edit(state, row.tlv, new_text)
    end
  end

  defp apply_edit(state, tlv, new_text) do
    case Bindocsis.ValueParser.parse_value(tlv.value_type, new_text) do
      {:error, reason} ->
        {:error, reason}

      {:ok, new_binary} ->
        raw_leaf = %{type: tlv.type, length: byte_size(new_binary), value: new_binary}

        tlvs =
          state.tlvs
          |> update_at_path(String.split(row_id(state), "."), raw_leaf)
          |> Bindocsis.TlvEnricher.unenrich_tlvs()
          |> Bindocsis.TlvEnricher.enrich_tlvs()

        rows = flatten(tlvs, state.expanded)

        selected =
          case Enum.find_index(rows, &(&1.id == row_id(state))) do
            nil -> 0
            idx -> idx
          end

        state = %{
          state
          | tlvs: tlvs,
            rows: rows,
            selected: selected,
            editing: nil,
            dirty: true,
            detail_scroll: 0,
            hex_scroll: 0,
            status_msg: "Updated TLV #{tlv.type} (unsaved changes)"
        }

        {:ok, revalidate(state)}
    end
  end

  defp row_id(%{editing: %{row_id: id}}), do: id

  defp update_at_path(tlvs, [idx_str], raw_leaf) do
    idx = String.to_integer(idx_str)
    List.replace_at(tlvs, idx, raw_leaf)
  end

  defp update_at_path(tlvs, [idx_str | rest], raw_leaf) do
    idx = String.to_integer(idx_str)

    case Enum.at(tlvs, idx) do
      %{subtlvs: subtlvs} = parent when is_list(subtlvs) ->
        List.replace_at(tlvs, idx, %{parent | subtlvs: update_at_path(subtlvs, rest, raw_leaf)})

      _ ->
        tlvs
    end
  end

  @doc """
  Replaces the config contents (after save) while preserving expansion
  and selection by row id. Clears the dirty flag.
  """
  @spec reload(t(), %{
          tlvs: [map()],
          raw_binary: binary(),
          file_size: non_neg_integer(),
          validation: map() | nil
        }) :: t()
  def reload(state, %{tlvs: tlvs, raw_binary: raw_binary, file_size: file_size} = args) do
    selected_id =
      case selected_row(state) do
        %{id: id} -> id
        nil -> nil
      end

    rows = flatten(tlvs, state.expanded)

    selected =
      case selected_id && Enum.find_index(rows, &(&1.id == selected_id)) do
        nil -> 0
        idx -> idx
      end

    %{
      state
      | tlvs: tlvs,
        raw_binary: raw_binary,
        file_size: file_size,
        validation: Map.get(args, :validation),
        rows: rows,
        selected: selected,
        editing: nil,
        dirty: false,
        detail_scroll: 0,
        hex_scroll: 0
    }
  end

  @doc "Re-runs validation against the currently encoded (unsaved) bytes."
  @spec revalidate(t()) :: t()
  def revalidate(state) do
    binary = encode_raw(state.tlvs)

    validation =
      case Bindocsis.ConfigValidator.validate(binary, docsis_version: state.docsis_version) do
        {:ok, result} -> result
        {:error, _} -> state.validation
      end

    %{state | validation: validation}
  end

  @doc "Encodes the current tree to binary (unenriched, MICs as currently stored)."
  @spec encode_raw([map()]) :: binary()
  def encode_raw(tlvs) do
    tlvs
    |> Bindocsis.TlvEnricher.unenrich_tlvs()
    |> Enum.map(&Bindocsis.Generators.BinaryGenerator.encode_single_tlv/1)
    |> IO.iodata_to_binary()
  end

  # -- row construction -------------------------------------------------

  defp visible_rows(%{search_active: true, search_query: query} = state)
       when query != "" do
    filter_rows(full_rows(state), query)
  end

  defp visible_rows(%{tlvs: tlvs, expanded: expanded}), do: flatten(tlvs, expanded)

  defp full_rows(%{tlvs: tlvs}), do: flatten(tlvs, expand_all_ids(tlvs))

  defp filter_rows(rows, query) do
    q = String.downcase(query)

    Enum.filter(rows, fn %{tlv: tlv} ->
      String.contains?(String.downcase("type #{tlv.type}"), q) or
        String.contains?(String.downcase(Map.get(tlv, :name, "")), q)
    end)
  end

  defp flatten(tlvs, expanded) do
    tlvs
    |> Enum.with_index()
    |> Enum.reduce([], fn {tlv, idx}, acc -> append_row(tlv, "#{idx}", 0, expanded, acc) end)
    |> Enum.reverse()
  end

  # IDs encode the path from the root (e.g. "3", "3.0") so selection
  # survives expand/collapse of other branches.
  defp append_row(tlv, id, depth, expanded, acc) do
    children = Map.get(tlv, :subtlvs, []) || []
    has_children = is_list(children) and length(children) > 0
    is_expanded = has_children and MapSet.member?(expanded, id)

    row = %{id: id, tlv: tlv, depth: depth, has_children: has_children, expanded: is_expanded}
    acc = [row | acc]

    acc =
      if is_expanded do
        children
        |> Enum.with_index()
        |> Enum.reduce(acc, fn {child, cidx}, child_acc ->
          append_row(child, "#{id}.#{cidx}", depth + 1, expanded, child_acc)
        end)
      else
        acc
      end

    acc
  end

  defp expand_all_ids(tlvs), do: do_expand_ids(tlvs, "root") |> MapSet.new()

  defp do_expand_ids(tlvs, prefix) do
    tlvs
    |> Enum.with_index()
    |> Enum.flat_map(fn {tlv, idx} ->
      id = if prefix == "root", do: "#{idx}", else: "#{prefix}.#{idx}"
      children = Map.get(tlv, :subtlvs, []) || []

      if is_list(children) and length(children) > 0,
        do: [id | do_expand_ids(children, id)],
        else: []
    end)
  end
end
