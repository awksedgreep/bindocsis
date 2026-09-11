defmodule BindocsisWeb.TLVBrowserLiveTest do
  use BindocsisWeb.ConnCase

  import Phoenix.LiveViewTest

  setup %{conn: conn} do
    %{conn: log_in_user(conn, user_fixture())}
  end

  test "shows a TLV detail for a numeric type", %{conn: conn} do
    {:ok, _lv, html} = live(conn, ~p"/tlvs/3")
    assert html =~ "Network Access Control"
  end

  test "non-numeric or out-of-range :tlv params do not crash (issue #11)", %{conn: conn} do
    {:ok, _lv, html} = live(conn, ~p"/tlvs/abc")
    assert html =~ "TLV Browser"

    {:ok, _lv, html} = live(conn, ~p"/tlvs/999")
    assert html =~ "TLV Browser"

    {:ok, _lv, html} = live(conn, ~p"/tlvs/-1")
    assert html =~ "TLV Browser"
  end
end
