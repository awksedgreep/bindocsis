defmodule BindocsisWeb.ConfigEditorLiveTest do
  use BindocsisWeb.ConnCase

  import Phoenix.LiveViewTest

  alias BindocsisWeb.ConfigStore

  @config <<3, 1, 1, 18, 1, 5, 0xFF>>

  setup %{conn: conn} do
    {:ok, id} = ConfigStore.store(@config, name: "editor_test.cm")
    on_exit(fn -> ConfigStore.delete(id) end)
    %{conn: log_in_user(conn, user_fixture()), id: id}
  end

  test "renders the editor", %{conn: conn, id: id} do
    {:ok, _lv, html} = live(conn, ~p"/configs/#{id}/edit")
    assert html =~ "Edit Config"
    assert html =~ "2 TLVs"
  end

  test "malformed phx-value params are ignored instead of crashing (issue #11)", %{
    conn: conn,
    id: id
  } do
    {:ok, lv, _html} = live(conn, ~p"/configs/#{id}/edit")

    render_click(lv, "focus-tlv", %{"path" => "0", "type" => "abc"})
    render_click(lv, "focus-tlv", %{"path" => "x.y", "type" => "3", "parent-type" => "zz"})
    render_click(lv, "edit-tlv", %{"path" => "a.b"})
    render_click(lv, "select-add-tlv", %{"type" => "abc"})
    render_click(lv, "quick-add-tlv", %{"type" => "999"})
    render_click(lv, "duplicate-tlv", %{"path" => "nope"})
    render_click(lv, "duplicate-tlv", %{"path" => "42"})
    render_click(lv, "move-tlv-up", %{"path" => "-1"})
    render_click(lv, "move-tlv-down", %{"path" => "1.0"})
    render_click(lv, "delete-tlv", %{"path" => "abc"})
    render_click(lv, "delete-tlv", %{"path" => "42"})
    render_click(lv, "toggle-expand", %{"path" => "a.b"})

    html = render(lv)
    assert html =~ "Edit Config"
    # No TLV was added, duplicated or removed by the bogus events
    assert html =~ "2 TLVs"
    refute html =~ "Unsaved changes"
  end

  test "valid reorder and delete still work", %{conn: conn, id: id} do
    {:ok, lv, _html} = live(conn, ~p"/configs/#{id}/edit")

    render_click(lv, "duplicate-tlv", %{"path" => "0"})
    assert render(lv) =~ "3 TLVs"

    render_click(lv, "delete-tlv", %{"path" => "2"})
    render_click(lv, "confirm-delete", %{})

    html = render(lv)
    assert html =~ "2 TLVs"
    assert html =~ "Unsaved changes"
  end
end
