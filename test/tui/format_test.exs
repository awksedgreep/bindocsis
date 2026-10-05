defmodule Bindocsis.Tui.FormatTest do
  use ExUnit.Case, async: true

  alias Bindocsis.Tui.{Format, State}

  defp leaf do
    %{
      type: 3,
      length: 1,
      value: <<1>>,
      value_type: :boolean,
      formatted_value: "Enabled",
      name: "Web Access Control",
      description: "Controls web access",
      docsis_category: :management,
      introduced_version: "1.0",
      subtlvs: []
    }
  end

  defp state(tlvs \\ [leaf()]) do
    State.load(%{path: "modem.cm", file_size: 32, tlvs: tlvs, raw_binary: <<>>, validation: nil})
  end

  test "tree_label marks leaves and branches" do
    [row] = state().rows
    assert Format.tree_label(row) =~ "T3 Web Access Control (1B)"
    refute Format.tree_label(row) =~ "▸"
  end

  test "detail_lines shows decoded value and spec reference" do
    lines = Format.detail_lines(leaf())
    assert Enum.any?(lines, &(&1 =~ "Web Access Control (Type 3)"))
    assert Enum.any?(lines, &(&1 =~ "Value: Enabled"))
    assert Enum.any?(lines, &(&1 =~ "Controls web access"))
  end

  test "detail_lines notes compound values" do
    compound = Map.put(leaf(), :subtlvs, [leaf(), leaf()])
    lines = Format.detail_lines(compound)
    assert Enum.any?(lines, &(&1 =~ "compound: 2 sub-TLVs"))
  end

  test "hex_lines dumps offsets, hex and ascii" do
    tlv = Map.put(leaf(), :value, <<"ABCDEFGHabcdefgh", 0, 255>>)
    [first | _] = Format.hex_lines(tlv)
    assert first =~ "0000"
    assert first =~ "41 42 43"
    assert first =~ "|ABCDEFGHabcdefgh|"
  end

  test "hex_lines handles empty and non-binary values" do
    assert Format.hex_lines(Map.put(leaf(), :value, <<>>)) == ["<empty value>"]
    assert Format.hex_lines(Map.put(leaf(), :value, %{a: 1})) == ["<non-binary value>"]
  end

  test "header/footer reflect state" do
    s = state()
    assert Format.header_text(s) =~ "modem.cm"
    assert Format.header_text(s) =~ "VALID"
    assert Format.footer_text(s) =~ "j/k: move"

    searching = State.start_search(s)
    assert Format.footer_text(searching) =~ "Type to filter"
  end

  test "validation_lines caps output and handles nil" do
    assert Format.validation_lines(state(), 10) == ["File was not validated"]

    violations = for i <- 1..5, do: %{severity: :major, description: "issue #{i}"}
    s = %{state() | validation: %{docsis_version: "3.1", violations: violations, warnings: []}}
    lines = Format.validation_lines(s, 3)
    assert length(lines) == 4
    assert List.last(lines) =~ "2 more"
  end

  test "help_lines documents the bindings" do
    help = Format.help_lines() |> Enum.join("\n")
    assert help =~ "expand / collapse"
    assert help =~ "quit"
  end
end
