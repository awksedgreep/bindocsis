defmodule BindocsisWeb.ConfigViewerLiveTest do
  use BindocsisWeb.ConnCase

  import Phoenix.LiveViewTest

  alias BindocsisWeb.ConfigStore

  # TLV 3 (Network Access Control) + TLV 24 (Upstream Service Flow) with one
  # sub-TLV, terminated. Enough for tree/select paths.
  @config <<3, 1, 1, 24, 4, 1, 2, 0, 1, 0xFF>>

  setup %{conn: conn} do
    {:ok, id} = ConfigStore.store(@config, name: "viewer_test.cm")
    on_exit(fn -> ConfigStore.delete(id) end)
    %{conn: log_in_user(conn, user_fixture()), id: id}
  end

  test "renders the stored config", %{conn: conn, id: id} do
    {:ok, _lv, html} = live(conn, ~p"/configs/#{id}")
    assert html =~ "viewer_test.cm"
  end

  test "ignores an unknown view mode instead of creating an atom (issue #11)", %{
    conn: conn,
    id: id
  } do
    {:ok, lv, _html} = live(conn, ~p"/configs/#{id}")

    bogus = "mode_#{System.unique_integer([:positive])}"
    render_click(lv, "set-view", %{"mode" => bogus})

    # LiveView still alive, still on the default view
    assert render(lv) =~ "viewer_test.cm"
    assert_raise ArgumentError, fn -> String.to_existing_atom(bogus) end

    render_click(lv, "set-view", %{"mode" => "hex"})
    assert render(lv) =~ "viewer_test.cm"
  end

  test "survives a malformed select-tlv path (issue #11)", %{conn: conn, id: id} do
    {:ok, lv, _html} = live(conn, ~p"/configs/#{id}")

    render_click(lv, "select-tlv", %{"path" => "a.b"})
    render_click(lv, "select-tlv", %{"path" => "0..1"})
    render_click(lv, "select-tlv", %{"path" => "99"})

    assert render(lv) =~ "viewer_test.cm"
  end
end
