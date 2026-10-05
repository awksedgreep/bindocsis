defmodule Bindocsis.Tui.StateTest do
  use ExUnit.Case, async: true

  alias Bindocsis.Tui.State

  defp leaf(type, name) do
    %{
      type: type,
      length: 1,
      value: <<1>>,
      value_type: :boolean,
      formatted_value: "Enabled",
      name: name,
      description: "desc",
      subtlvs: []
    }
  end

  defp compound do
    %{
      type: 24,
      length: 6,
      value: <<1, 2, 3, 4, 5, 6>>,
      value_type: :compound,
      formatted_value: nil,
      name: "Downstream Service Flow",
      description: "flow",
      subtlvs: [leaf(1, "Service Flow Reference"), leaf(2, "Service Flow ID")]
    }
  end

  defp load(tlvs \\ [leaf(3, "Web Access Control"), compound()]) do
    State.load(%{
      path: "test.cm",
      file_size: 128,
      tlvs: tlvs,
      raw_binary: <<0, 1>>,
      validation: nil
    })
  end

  test "load expands all branches and selects the first row" do
    state = load()
    assert length(state.rows) == 4
    assert state.selected == 0
    assert Enum.map(state.rows, & &1.id) == ["0", "1", "1.0", "1.1"]
    assert State.selected_row(state).tlv.type == 3
  end

  test "move clamps to visible rows" do
    state = load()
    assert State.move(state, 99).selected == 3
    assert state |> State.move(99) |> State.move(-99) |> Map.get(:selected) == 0
  end

  test "toggle collapses and re-expands a compound row" do
    state = load() |> State.move(1)
    collapsed = State.toggle(state)
    assert Enum.map(collapsed.rows, & &1.id) == ["0", "1"]
    # Selection stays on the toggled row.
    assert State.selected_row(collapsed).id == "1"

    expanded = State.toggle(collapsed)
    assert Enum.map(expanded.rows, & &1.id) == ["0", "1", "1.0", "1.1"]
  end

  test "toggle on a leaf sets a status message" do
    state = load() |> State.toggle()
    assert state.status_msg =~ "Leaf TLV"
    assert length(state.rows) == 4
  end

  test "search filters by name and type, Esc clears" do
    state = load() |> State.start_search() |> State.apply_search("service flow")
    assert length(state.rows) == 3
    assert Enum.all?(state.rows, &(&1.tlv.type == 24 or &1.tlv.type in [1, 2]))

    cleared = State.stop_search(state, true)
    assert cleared.search_query == ""
    assert length(cleared.rows) == 4
  end

  test "search by type number" do
    state = load() |> State.start_search() |> State.apply_search("type 3")
    assert Enum.map(state.rows, & &1.tlv.type) == [3]
  end

  test "Enter keeps the filter applied" do
    state = load() |> State.start_search() |> State.apply_search("type 3")
    kept = State.stop_search(state, false)
    refute kept.search_active
    assert kept.search_query == "type 3"
    assert Enum.map(kept.rows, & &1.tlv.type) == [3]
  end

  test "cycle_focus rotates tree -> detail -> hex -> tree" do
    state = load()
    assert state.focus == :tree
    assert State.cycle_focus(state).focus == :detail
    assert state |> State.cycle_focus() |> State.cycle_focus() |> Map.get(:focus) == :hex

    assert state
           |> State.cycle_focus()
           |> State.cycle_focus()
           |> State.cycle_focus()
           |> Map.get(:focus) == :tree
  end

  test "scroll_focused only affects the focused pane" do
    state = load()
    assert State.scroll_focused(state, 5) == state

    detail = %{state | focus: :detail} |> State.scroll_focused(5)
    assert detail.detail_scroll == 5
    assert detail.hex_scroll == 0

    hex = %{state | focus: :hex} |> State.scroll_focused(3)
    assert hex.hex_scroll == 3
  end

  test "issue_count and valid? handle nil validation" do
    state = load()
    assert State.issue_count(state) == 0
    assert State.valid?(state)
  end

  test "issue_count sums violations and warnings" do
    validation = %{
      is_valid: false,
      violations: [%{description: "a"}],
      warnings: [%{description: "b"}]
    }

    state = %{load() | validation: validation}
    assert State.issue_count(state) == 2
    refute State.valid?(state)
  end

  test "loads a real fixture end to end" do
    {:ok, tlvs} = Bindocsis.parse_file("test/fixtures/docsis1_0_basic.cm")
    enriched = Bindocsis.TlvEnricher.enrich_tlvs(tlvs)

    state =
      State.load(%{
        path: "basic.cm",
        file_size: 64,
        tlvs: enriched,
        raw_binary: <<>>,
        validation: nil
      })

    assert length(state.rows) >= length(enriched)
    assert State.selected_row(state) != nil
  end
end
