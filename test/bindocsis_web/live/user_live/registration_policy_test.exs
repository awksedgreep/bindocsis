defmodule BindocsisWeb.UserLive.RegistrationPolicyTest do
  use BindocsisWeb.ConnCase

  import Phoenix.LiveViewTest

  setup do
    original = Application.get_env(:bindocsis, :registration)
    on_exit(fn -> Application.put_env(:bindocsis, :registration, original) end)
    :ok
  end

  test "closed registration redirects the page and hides the links (issue #13)", %{conn: conn} do
    Application.put_env(:bindocsis, :registration, mode: :closed)

    assert {:error, {:redirect, %{to: "/users/log-in", flash: flash}}} =
             live(conn, ~p"/users/register")

    assert flash["error"] =~ "Registration is closed"

    {:ok, _lv, html} = live(conn, ~p"/users/log-in")
    refute html =~ "Sign up"
    refute html =~ ~s(href="/users/register")
  end

  test "allowlist shows the changeset error for other addresses", %{conn: conn} do
    Application.put_env(:bindocsis, :registration, mode: :allowlist, allowlist: ["@ok.example"])

    {:ok, lv, _html} = live(conn, ~p"/users/register")

    html =
      lv
      |> form("#registration_form", user: %{"email" => "nope@other.example"})
      |> render_submit()

    assert html =~ "is not permitted to register"
  end

  test "registration submissions are throttled per client", %{conn: conn} do
    Application.put_env(:bindocsis, :registration, mode: :open)
    {:ok, lv, _html} = live(conn, ~p"/users/register")

    # 5 per hour are allowed; the first one succeeds and navigates away, so
    # exhaust the budget directly and submit once more.
    ip = "127.0.0.1"

    for _ <- 1..5,
        do: :ok = BindocsisWeb.RateLimiter.check({:register_ip, ip}, 5, :timer.hours(1))

    html =
      lv
      |> form("#registration_form", user: %{"email" => unique_user_email()})
      |> render_submit()

    assert html =~ "Too many registration attempts"
  end
end
