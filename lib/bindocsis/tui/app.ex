defmodule Bindocsis.Tui.App do
  @moduledoc """
  ExRatatui callback-runtime app for the `bindocsis tui` config browser.

  Thin event/render layer over `Bindocsis.Tui.State` (transitions) and
  `Bindocsis.Tui.Format` (view model). Rendering is factored through
  `scene/2` so headless tests can assert on the buffer without a TTY
  (see the ExRatatui testing guide's `scene/2` pattern).
  """

  use ExRatatui.App

  alias ExRatatui.Event
  alias ExRatatui.Layout
  alias ExRatatui.Layout.Rect
  alias ExRatatui.Style
  alias ExRatatui.Widgets.{Block, Clear, List, Paragraph, Popup, TextInput}
  alias Bindocsis.Tui.{Format, Operations, State}

  @impl true
  def mount(opts) do
    case Keyword.fetch(opts, :state) do
      {:ok, state} -> {:ok, state}
      :error -> {:error, "TUI app requires a prebuilt :state (see Bindocsis.Tui.run/1)"}
    end
  end

  @impl true
  def render(state, frame) do
    scene(state, %Rect{x: 0, y: 0, width: frame.width, height: frame.height})
  end

  @doc """
  Pure scene builder: state + area → `[{widget, rect}]` render list.
  Used by `render/2` and by headless buffer tests.
  """
  @spec scene(State.t(), Rect.t()) :: [{struct(), Rect.t()}]
  def scene(state, area) do
    [header_rect, body_rect, footer_rect] =
      Layout.split(area, :vertical, [{:length, 3}, {:min, 0}, {:length, 1}])

    [tree_rect, right_rect] =
      Layout.split(body_rect, :horizontal, [{:percentage, 38}, {:fill, 1}])

    [detail_rect, hex_rect] =
      Layout.split(right_rect, :vertical, [{:percentage, 55}, {:fill, 1}])

    selected_tlv =
      case State.selected_row(state) do
        nil -> nil
        %{tlv: tlv} -> tlv
      end

    base = [
      {header_widget(state), header_rect},
      {tree_widget(state), tree_rect},
      {detail_widget(state, selected_tlv), detail_rect},
      {hex_widget(state, selected_tlv), hex_rect},
      {footer_widget(state), footer_rect}
    ]

    base ++ overlays(state, area)
  end

  @impl true
  # Edit mode captures every key for the input (including q, v, /,
  # which would otherwise trigger commands). Must stay first.
  def handle_event(%Event.Key{code: "esc"}, %{editing: editing} = state)
      when not is_nil(editing),
      do: {:noreply, State.cancel_edit(state)}

  def handle_event(%Event.Key{code: "enter"}, %{editing: editing} = state)
      when not is_nil(editing) do
    text = ExRatatui.text_input_get_value(editing.input)

    case State.commit_edit(state, text) do
      {:ok, updated} -> {:noreply, updated}
      {:error, reason} -> {:noreply, State.set_edit_error(state, reason)}
    end
  end

  def handle_event(%Event.Key{code: code}, %{editing: editing} = state)
      when not is_nil(editing) and code not in ["tab"] do
    # NOTE: the input handle is mutated in place; handle_key returns :ok.
    :ok = ExRatatui.text_input_handle_key(editing.input, code)
    {:noreply, state}
  end

  def handle_event(%Event.Key{code: "q"}, %{pending_quit: false, dirty: false} = state),
    do: {:stop, state}

  def handle_event(%Event.Key{code: "q"}, %{pending_quit: false} = state),
    do: {:noreply, %{state | pending_quit: true}}

  def handle_event(%Event.Key{code: "q"}, state), do: {:stop, state}
  def handle_event(%Event.Key{code: "c", modifiers: ["ctrl"]}, state), do: {:stop, state}

  # Unsaved-changes quit confirmation.
  def handle_event(%Event.Key{code: "y"}, %{pending_quit: true} = state), do: {:stop, state}

  def handle_event(%Event.Key{code: code}, %{pending_quit: true} = state)
      when code in ["n", "esc"],
      do: {:noreply, %{state | pending_quit: false}}

  # Export overlay navigation.
  def handle_event(%Event.Key{code: "esc"}, %{exporting: exporting} = state)
      when not is_nil(exporting),
      do: {:noreply, %{state | exporting: nil}}

  def handle_event(%Event.Key{code: code}, %{exporting: %{selected: sel}} = state)
      when code in ["j", "down"] do
    max = length(Format.export_formats()) - 1
    {:noreply, %{state | exporting: %{selected: min(max, sel + 1)}}}
  end

  def handle_event(%Event.Key{code: code}, %{exporting: %{selected: sel}} = state)
      when code in ["k", "up"] do
    {:noreply, %{state | exporting: %{selected: max(0, sel - 1)}}}
  end

  def handle_event(%Event.Key{code: "enter"}, %{exporting: %{selected: sel}} = state) do
    {format, _label} = Enum.at(Format.export_formats(), sel)
    path = Format.export_path(state.path, format)

    case Operations.export(state, path, format) do
      {:ok, message} ->
        {:noreply, %{state | exporting: nil, status_msg: message}}

      {:error, reason} ->
        {:noreply, %{state | exporting: nil, status_msg: "Export failed: #{reason}"}}
    end
  end

  # Search mode captures most keys for the input.
  def handle_event(%Event.Key{code: "esc"}, %{search_active: true} = state),
    do: {:noreply, State.stop_search(state, true)}

  def handle_event(%Event.Key{code: "enter"}, %{search_active: true} = state),
    do: {:noreply, State.stop_search(state, false)}

  def handle_event(%Event.Key{code: code} = event, %{search_active: true} = state)
      when code not in ["up", "down", "left", "right", "tab"] do
    _ = event
    # NOTE: the input handle is mutated in place; handle_key returns :ok.
    :ok = ExRatatui.text_input_handle_key(state.search_input, code)
    query = ExRatatui.text_input_get_value(state.search_input)
    {:noreply, State.apply_search(state, query)}
  end

  # Overlays toggle.
  def handle_event(%Event.Key{code: "?"}, state), do: {:noreply, State.toggle_help(state)}
  def handle_event(%Event.Key{code: "v"}, state), do: {:noreply, State.toggle_validation(state)}

  def handle_event(%Event.Key{code: "esc"}, state) do
    cond do
      state.show_help -> {:noreply, State.toggle_help(state)}
      state.show_validation -> {:noreply, State.toggle_validation(state)}
      state.search_query != "" -> {:noreply, State.stop_search(state, true)}
      state.focus != :tree -> {:noreply, %{state | focus: :tree}}
      true -> {:noreply, state}
    end
  end

  # Navigation + pane control.
  def handle_event(%Event.Key{code: code}, state) when code in ["j", "down"] do
    {:noreply,
     if(state.focus == :tree, do: State.move(state, 1), else: State.scroll_focused(state, 1))}
  end

  def handle_event(%Event.Key{code: code}, state) when code in ["k", "up"] do
    {:noreply,
     if(state.focus == :tree, do: State.move(state, -1), else: State.scroll_focused(state, -1))}
  end

  def handle_event(%Event.Key{code: "enter"}, %{focus: :tree} = state),
    do: {:noreply, State.toggle(state)}

  def handle_event(%Event.Key{code: code}, state) when code in ["tab", "right", "left"] do
    {:noreply, State.cycle_focus(state)}
  end

  def handle_event(%Event.Key{code: "/"}, %{focus: :tree} = state),
    do: {:noreply, State.start_search(state)}

  def handle_event(%Event.Key{code: "e"}, %{focus: :tree, exporting: nil} = state) do
    row = State.selected_row(state)
    initial = Format.edit_text(row && row.tlv)

    case State.start_edit(state, initial) do
      {:ok, updated} -> {:noreply, updated}
      {:error, reason} -> {:noreply, %{state | status_msg: reason}}
    end
  end

  def handle_event(%Event.Key{code: "s"}, %{exporting: nil} = state) do
    case Operations.save(state, state.path) do
      {:ok, updated, message} -> {:noreply, %{updated | status_msg: message}}
      {:error, reason} -> {:noreply, %{state | status_msg: "Save failed: #{reason}"}}
    end
  end

  def handle_event(%Event.Key{code: "X"}, %{exporting: nil} = state),
    do: {:noreply, %{state | exporting: %{selected: 0}}}

  def handle_event(_event, state), do: {:noreply, state}

  # -- widgets ----------------------------------------------------------

  defp header_widget(state) do
    validity_style =
      if State.valid?(state),
        do: %Style{fg: :green, modifiers: [:bold]},
        else: %Style{fg: :red, modifiers: [:bold]}

    %Paragraph{
      text: Format.header_text(state),
      style: validity_style,
      block: %Block{title: " bindocsis tui ", borders: [:all], border_type: :rounded}
    }
  end

  defp tree_widget(state) do
    %List{
      items: Enum.map(state.rows, &Format.tree_label/1),
      selected: state.selected,
      highlight_symbol: ">> ",
      highlight_style: %Style{fg: :yellow, modifiers: [:bold]},
      block: pane_block(" TLVs ", state.focus == :tree)
    }
  end

  defp detail_widget(state, tlv) do
    %Paragraph{
      text: tlv |> Format.detail_lines() |> Enum.join("\n"),
      wrap: true,
      scroll: {state.detail_scroll, 0},
      block: pane_block(" Detail ", state.focus == :detail)
    }
  end

  defp hex_widget(state, tlv) do
    %Paragraph{
      text: tlv |> Format.hex_lines() |> Enum.join("\n"),
      scroll: {state.hex_scroll, 0},
      block: pane_block(" Hex ", state.focus == :hex)
    }
  end

  defp footer_widget(%{search_active: true} = state) do
    query = ExRatatui.text_input_get_value(state.search_input)

    %Paragraph{
      text: "/#{query}█  —  #{Format.footer_text(state)}",
      style: %Style{fg: :yellow}
    }
  end

  defp footer_widget(state) do
    status = if state.status_msg, do: "#{state.status_msg} • ", else: ""
    %Paragraph{text: status <> Format.footer_text(state), style: %Style{fg: :gray}}
  end

  defp overlays(state, area) do
    cond do
      not is_nil(state.editing) ->
        edit_overlay(state, area)

      not is_nil(state.exporting) ->
        export_overlay(state, area)

      state.pending_quit ->
        [
          {%Clear{}, area},
          {%Popup{
             content: %Paragraph{
               text: "Unsaved changes will be lost.\n\nQuit without saving?  (y / n)",
               alignment: :center
             },
             percent_width: 50,
             percent_height: 30,
             block: %Block{title: " Quit? ", borders: [:all], border_type: :double}
           }, area}
        ]

      state.show_help ->
        [
          {%Clear{}, area},
          {%Popup{
             content: %Paragraph{text: Format.help_lines() |> Enum.join("\n")},
             percent_width: 60,
             percent_height: 60,
             block: %Block{title: " Help ", borders: [:all], border_type: :double}
           }, area}
        ]

      state.show_validation ->
        [
          {%Clear{}, area},
          {%Popup{
             content: %Paragraph{
               text: state |> Format.validation_lines(40) |> Enum.join("\n"),
               wrap: true
             },
             percent_width: 70,
             percent_height: 60,
             block: %Block{title: " Validation issues ", borders: [:all], border_type: :double}
           }, area}
        ]

      true ->
        []
    end
  end

  defp edit_overlay(%{editing: %{input: input, error: error}} = state, area) do
    row = State.selected_row(state)
    tlv = row && row.tlv
    {input_rect, hint_rect} = centered_box(area, 64, 8)

    hint =
      case error do
        nil -> "Type: #{tlv_value_type(tlv)} • Enter: commit • Esc: cancel"
        reason -> "Error: #{reason}"
      end

    hint_style = if error, do: %Style{fg: :red}, else: %Style{fg: :gray}

    [
      {%Clear{}, area},
      {%TextInput{
         state: input,
         style: %Style{fg: :white},
         cursor_style: %Style{bg: :white, fg: :black},
         block: %Block{title: Format.edit_title(tlv), borders: [:all], border_type: :double}
       }, input_rect},
      {%Paragraph{text: hint, style: hint_style}, hint_rect}
    ]
  end

  defp export_overlay(%{exporting: %{selected: sel}}, area) do
    {list_rect, _} = centered_box(area, 44, 10)
    items = Format.export_formats() |> Enum.map(&elem(&1, 1))

    [
      {%Clear{}, area},
      {%List{
         items: items,
         selected: sel,
         highlight_symbol: ">> ",
         highlight_style: %Style{fg: :yellow, modifiers: [:bold]},
         block: %Block{title: " Export format ", borders: [:all], border_type: :double}
       }, list_rect}
    ]
  end

  # Centered box of at most (max_w × max_h); returns {top_rect(3 high), rest}.
  defp centered_box(area, max_w, max_h) do
    w = max(20, min(max_w, area.width - 4))
    h = max(5, min(max_h, area.height - 4))
    x = div(area.width - w, 2)
    y = div(area.height - h, 2)
    box = %Rect{x: x, y: y, width: w, height: h}
    [top, rest] = Layout.split(box, :vertical, [{:length, 3}, {:fill, 1}])
    {top, rest}
  end

  defp tlv_value_type(nil), do: "unknown"
  defp tlv_value_type(tlv), do: tlv |> Map.get(:value_type, :unknown) |> to_string()

  defp pane_block(title, focused) do
    color = if focused, do: :yellow, else: :gray

    %Block{title: title, borders: [:all], border_type: :rounded, border_style: %Style{fg: color}}
  end
end
