defmodule Bindocsis.Tui.AppTest do
  use ExUnit.Case, async: true

  alias ExRatatui.Event
  alias ExRatatui.Layout.Rect
  alias ExRatatui.Runtime
  alias Bindocsis.Tui.{App, State}

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

  defp test_state do
    State.load(%{
      path: "modem.cm",
      file_size: 32,
      tlvs: [leaf(3, "Web Access Control"), leaf(18, "Max CPE")],
      raw_binary: <<>>,
      validation: nil
    })
  end

  defp start_app(state \\ test_state()) do
    start_supervised!({App, [state: state, name: nil, test_mode: {80, 24}]})
  end

  test "scene renders header, tree rows and panes to the headless buffer" do
    terminal = ExRatatui.init_test_terminal(80, 24)

    :ok =
      ExRatatui.draw(terminal, App.scene(test_state(), %Rect{x: 0, y: 0, width: 80, height: 24}))

    content = ExRatatui.get_buffer_content(terminal)

    assert content =~ "bindocsis tui"
    assert content =~ "modem.cm"
    assert content =~ "T3 Web Access Control"
    assert content =~ "T18 Max CPE"
    assert content =~ "Detail"
    assert content =~ "Hex"
  end

  test "j/k move selection" do
    pid = start_app()
    :ok = Runtime.inject_event(pid, %Event.Key{code: "j", kind: "press"})
    assert :sys.get_state(pid).user_state.selected == 1

    :ok = Runtime.inject_event(pid, %Event.Key{code: "k", kind: "press"})
    assert :sys.get_state(pid).user_state.selected == 0
  end

  test "q stops the app" do
    pid = start_app()
    ref = Process.monitor(pid)
    :ok = Runtime.inject_event(pid, %Event.Key{code: "q", kind: "press"})
    assert_receive {:DOWN, ^ref, :process, ^pid, _}, 1_000
  end

  test "toggle overlays with ? and v" do
    pid = start_app()
    :ok = Runtime.inject_event(pid, %Event.Key{code: "?", kind: "press"})
    assert :sys.get_state(pid).user_state.show_help

    :ok = Runtime.inject_event(pid, %Event.Key{code: "v", kind: "press"})
    assert :sys.get_state(pid).user_state.show_validation
  end

  test "mount requires a prebuilt state" do
    assert {:error, _} = App.mount([])
  end

  test "e opens the editor on leaves, Esc cancels" do
    pid = start_app()
    :ok = Runtime.inject_event(pid, %Event.Key{code: "e", kind: "press"})
    assert :sys.get_state(pid).user_state.editing != nil

    :ok = Runtime.inject_event(pid, %Event.Key{code: "esc", kind: "press"})
    final = :sys.get_state(pid).user_state
    assert is_nil(final.editing)
    refute final.dirty
  end

  test "e on a compound row refuses with a status message" do
    compound = %{
      type: 24,
      length: 2,
      value: <<1, 2>>,
      value_type: :compound,
      formatted_value: nil,
      name: "Flow",
      description: "d",
      subtlvs: [leaf(1, "Ref")]
    }

    state =
      State.load(%{path: "x.cm", file_size: 8, tlvs: [compound], raw_binary: <<>>, validation: nil})

    pid = start_app(state)
    :ok = Runtime.inject_event(pid, %Event.Key{code: "e", kind: "press"})
    final = :sys.get_state(pid).user_state
    assert is_nil(final.editing)
    assert final.status_msg =~ "Compound TLV"
  end

  test "invalid commit keeps the editor open" do
    pid = start_app()
    :ok = Runtime.inject_event(pid, %Event.Key{code: "e", kind: "press"})
    :ok = Runtime.inject_event(pid, %Event.Key{code: "z", kind: "press"})
    :ok = Runtime.inject_event(pid, %Event.Key{code: "enter", kind: "press"})
    final = :sys.get_state(pid).user_state
    assert final.editing != nil
  end

  test "q with unsaved changes asks for confirmation" do
    pid = start_app(%{test_state() | dirty: true})
    :ok = Runtime.inject_event(pid, %Event.Key{code: "q", kind: "press"})
    mid = :sys.get_state(pid).user_state
    assert mid.pending_quit
    assert Process.alive?(pid)

    ref = Process.monitor(pid)
    :ok = Runtime.inject_event(pid, %Event.Key{code: "y", kind: "press"})
    assert_receive {:DOWN, ^ref, :process, ^pid, _}, 1_000
  end

  test "s saves to disk and clears dirty" do
    tmp = Path.join(System.tmp_dir!(), "tui_app_save_#{:rand.uniform(100_000)}.cm")
    File.cp!("test/fixtures/docsis1_0_basic.cm", tmp)
    on_exit(fn -> File.rm(tmp) end)

    bin = File.read!(tmp)
    {:ok, tlvs} = Bindocsis.parse(bin)

    state =
      State.load(%{
        path: tmp,
        file_size: byte_size(bin),
        tlvs: Bindocsis.TlvEnricher.enrich_tlvs(tlvs),
        raw_binary: bin,
        validation: nil
      })

    pid = start_app(%{state | dirty: true})
    :ok = Runtime.inject_event(pid, %Event.Key{code: "s", kind: "press"})
    final = :sys.get_state(pid).user_state
    refute final.dirty
    assert final.status_msg =~ "Saved #{tmp}"

    {:ok, back} = Bindocsis.parse(File.read!(tmp))
    assert {:ok, :valid} = Bindocsis.Crypto.MIC.validate_cm_mic(back)
  end

  test "X opens the export overlay, Esc closes it" do
    pid = start_app()
    :ok = Runtime.inject_event(pid, %Event.Key{code: "X", kind: "press"})
    assert :sys.get_state(pid).user_state.exporting == %{selected: 0}

    :ok = Runtime.inject_event(pid, %Event.Key{code: "esc", kind: "press"})
    assert is_nil(:sys.get_state(pid).user_state.exporting)
  end
end
