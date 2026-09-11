defmodule BindocsisWeb.DashboardUploadTest do
  use BindocsisWeb.ConnCase

  import Phoenix.LiveViewTest

  alias BindocsisWeb.ConfigStore

  setup %{conn: conn} do
    ids_before = ConfigStore.list_all() |> Enum.map(& &1.id) |> MapSet.new()

    on_exit(fn ->
      ConfigStore.list_all()
      |> Enum.reject(&MapSet.member?(ids_before, &1.id))
      |> Enum.each(&ConfigStore.delete(&1.id))
    end)

    %{conn: log_in_user(conn, user_fixture())}
  end

  test "rejects file types the UI does not advertise (issue #12)", %{conn: conn} do
    {:ok, lv, _html} = live(conn, ~p"/")
    count_before = ConfigStore.count()

    upload =
      file_input(lv, "#upload-form", :config, [
        %{name: "payload.exe", content: <<0x4D, 0x5A, 0, 0>>, type: "application/octet-stream"}
      ])

    # Depending on timing the server either refuses the chunks
    # ({:error, :not_allowed}) or flags the entry; either way the consume step
    # re-checks the name and nothing reaches the store.
    _ = render_upload(upload, "payload.exe")

    lv |> element("#upload-form") |> render_submit()
    assert ConfigStore.count() == count_before
  end

  test "stores an accepted .cm upload and navigates to it", %{conn: conn} do
    {:ok, lv, _html} = live(conn, ~p"/")
    count_before = ConfigStore.count()

    upload =
      file_input(lv, "#upload-form", :config, [
        %{name: "good.cm", content: <<3, 1, 1, 18, 1, 5, 0xFF>>, type: "application/octet-stream"}
      ])

    assert render_upload(upload, "good.cm") =~ "good.cm"

    lv |> element("#upload-form") |> render_submit()
    {path, _flash} = assert_redirect(lv)
    assert path =~ ~r"^/configs/[A-Za-z0-9_-]+$"
    assert ConfigStore.count() == count_before + 1
  end

  test "an accepted extension with unparseable content is reported, not stored", %{conn: conn} do
    {:ok, lv, _html} = live(conn, ~p"/")
    count_before = ConfigStore.count()

    upload =
      file_input(lv, "#upload-form", :config, [
        %{name: "broken.json", content: "{not json", type: "application/json"}
      ])

    render_upload(upload, "broken.json")
    html = lv |> element("#upload-form") |> render_submit()

    assert html =~ "Failed to upload"
    assert ConfigStore.count() == count_before
  end
end
