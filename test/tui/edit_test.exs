defmodule Bindocsis.Tui.EditTest do
  use ExUnit.Case, async: true

  alias Bindocsis.Tui.{Operations, State}

  defp leaf(type, name, value_type \\ :boolean, formatted \\ "Enabled", value \\ <<1>>) do
    %{
      type: type,
      length: byte_size(value),
      value: value,
      value_type: value_type,
      formatted_value: formatted,
      name: name,
      description: "desc",
      subtlvs: []
    }
  end

  defp compound do
    %{leaf(24, "Flow", :compound, nil, <<1, 2>>) | subtlvs: [leaf(1, "Ref"), leaf(2, "ID")]}
  end

  defp load(tlvs \\ [leaf(3, "Web Access Control"), compound()]) do
    State.load(%{path: "test.cm", file_size: 64, tlvs: tlvs, raw_binary: <<0>>, validation: nil})
  end

  defp start_edit!(state) do
    row = State.selected_row(state)
    {:ok, editing} = State.start_edit(state, row.tlv.formatted_value)
    editing
  end

  test "start_edit opens on leaves, refuses compounds" do
    assert {:ok, editing} = State.start_edit(load(), "Enabled")
    assert editing.editing.row_id == "0"

    compound_state = load() |> State.move(1)
    assert {:error, reason} = State.start_edit(compound_state, "")
    assert reason =~ "Compound TLV"
    assert is_nil(compound_state.editing)
  end

  test "commit_edit updates bytes, marks dirty, keeps expansion" do
    state = load() |> start_edit!()
    assert {:ok, updated} = State.commit_edit(state, "disabled")

    assert updated.dirty
    assert is_nil(updated.editing)
    assert updated.status_msg =~ "Updated TLV 3"
    # Tree shape preserved (compound still expanded).
    assert Enum.map(updated.rows, & &1.id) == ["0", "1", "1.0", "1.1"]
    # New bytes survived the unenrich/re-enrich round trip.
    assert State.selected_row(updated).tlv.value == <<0>>
  end

  test "commit_edit rejects invalid input and stays open" do
    state = load() |> start_edit!()
    assert {:error, _reason} = State.commit_edit(state, "not-a-boolean")
    assert State.set_edit_error(state, "bad").editing.error == "bad"
    refute load().dirty
  end

  test "commit_edit edits nested sub-TLVs and re-encodes the parent" do
    state = load() |> State.move(2)
    assert State.selected_row(state).id == "1.0"

    editing = start_edit!(state)
    assert {:ok, updated} = State.commit_edit(editing, "disabled")

    parent = Enum.find(updated.tlvs, &(&1.type == 24))
    assert parent.value != <<1, 2>>
    assert updated.dirty
  end

  test "commit_edit supports hex-string fallback leaves" do
    hex_leaf = leaf(43, "Vendor", :hex_string, "AB CD", <<0xAB, 0xCD>>)
    state = load([hex_leaf]) |> start_edit!()
    assert {:ok, updated} = State.commit_edit(state, "00 FF")
    assert State.selected_row(updated).tlv.value == <<0x00, 0xFF>>
  end

  test "cancel_edit discards the edit" do
    state = load() |> start_edit!() |> State.cancel_edit()
    assert is_nil(state.editing)
    refute state.dirty
  end

  test "reload preserves expansion and clears dirty" do
    collapsed = load() |> State.move(1) |> State.toggle()
    assert Enum.map(collapsed.rows, & &1.id) == ["0", "1"]

    dirty = %{collapsed | dirty: true}

    reloaded =
      State.reload(dirty, %{tlvs: dirty.tlvs, raw_binary: <<1, 2>>, file_size: 2, validation: nil})

    refute reloaded.dirty
    assert Enum.map(reloaded.rows, & &1.id) == ["0", "1"]
    assert State.selected_row(reloaded).id == "1"
  end

  describe "Operations.save/2" do
    setup do
      tmp = Path.join(System.tmp_dir!(), "tui_save_#{:rand.uniform(100_000)}.cm")
      File.cp!("test/fixtures/docsis1_0_basic.cm", tmp)
      on_exit(fn -> File.rm(tmp) end)
      %{tmp: tmp}
    end

    defp load_path(path, opts \\ []) do
      bin = File.read!(path)
      {:ok, tlvs} = Bindocsis.parse(bin)
      enriched = Bindocsis.TlvEnricher.enrich_tlvs(tlvs)
      {:ok, validation} = Bindocsis.ConfigValidator.validate(bin, docsis_version: "3.1")

      State.load(
        %{
          path: path,
          file_size: byte_size(bin),
          tlvs: enriched,
          raw_binary: bin,
          validation: validation
        }
        |> Map.merge(Map.new(opts))
      )
    end

    test "saves with a valid recomputed CM MIC", %{tmp: tmp} do
      state = load_path(tmp)

      assert {:ok, saved, message} = Operations.save(state, tmp)
      assert message =~ "Saved #{tmp}"
      assert message =~ "CM MIC recomputed"
      refute saved.dirty

      {:ok, reloaded} = Bindocsis.parse(File.read!(tmp))
      assert {:ok, :valid} = Bindocsis.Crypto.MIC.validate_cm_mic(reloaded)
    end

    test "recomputes CMTS MIC when a shared secret is configured", %{tmp: tmp} do
      state = load_path(tmp, shared_secret: "test-secret")
      assert {:ok, _saved, message} = Operations.save(state, tmp)
      assert message =~ "CMTS MIC recomputed"

      {:ok, reloaded} = Bindocsis.parse(File.read!(tmp))

      assert {:ok, :valid} =
               Bindocsis.Crypto.MIC.validate_cmts_mic(reloaded, "test-secret")
    end

    test "save → edit → save round-trips an edited value", %{tmp: tmp} do
      state = load_path(tmp)
      # Edit the first leaf row to a valid new value.
      row = Enum.find(state.rows, &(!&1.has_children))
      state = %{state | selected: Enum.find_index(state.rows, &(&1.id == row.id))}
      {:ok, editing} = State.start_edit(state, row.tlv.formatted_value)
      new_text = if row.tlv.formatted_value == "Enabled", do: "disabled", else: "Enabled"

      assert {:ok, edited} = State.commit_edit(editing, new_text)
      assert edited.dirty
      assert {:ok, _saved, _msg} = Operations.save(edited, tmp)

      {:ok, back} = Bindocsis.parse(File.read!(tmp))
      assert {:ok, :valid} = Bindocsis.Crypto.MIC.validate_cm_mic(back)
    end

    test "export writes json and yaml that parse back", %{tmp: tmp} do
      state = load_path(tmp)
      json_path = tmp <> ".json"
      yaml_path = tmp <> ".yaml"
      on_exit(fn -> File.rm(json_path) && File.rm(yaml_path) end)

      assert {:ok, _} = Operations.export(state, json_path, :json)
      assert {:ok, _} = Operations.export(state, yaml_path, :yaml)
      assert {:ok, _} = Bindocsis.parse_file(json_path)
      assert {:ok, _} = Bindocsis.parse_file(yaml_path)
    end
  end
end
