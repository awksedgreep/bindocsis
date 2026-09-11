defmodule BindocsisWeb.UserLive.LoginThrottleTest do
  use BindocsisWeb.ConnCase

  import Phoenix.LiveViewTest

  alias BindocsisWeb.RateLimiter

  test "magic-link requests for one address are capped and stay uniform (issue #13)", %{
    conn: conn
  } do
    user = user_fixture()

    # Three requests are delivered with the uniform message...
    for _ <- 1..3 do
      {:ok, lv, _} = live(conn, ~p"/users/log-in")

      {:ok, _lv, html} =
        lv
        |> form("#login_form_magic", user: %{email: user.email})
        |> render_submit()
        |> follow_redirect(conn, ~p"/users/log-in")

      assert html =~ "If your email is in our system"
    end

    # ...the fourth is refused before any email is sent.
    {:ok, lv, _} = live(conn, ~p"/users/log-in")

    {:ok, _lv, html} =
      lv
      |> form("#login_form_magic", user: %{email: user.email})
      |> render_submit()
      |> follow_redirect(conn, ~p"/users/log-in")

    assert html =~ "Too many login requests"

    # An unknown address gets exactly the same treatment
    unknown = unique_user_email()
    for _ <- 1..3, do: RateLimiter.check({:magic_email, unknown}, 3, :timer.minutes(15))
    {:ok, lv, _} = live(conn, ~p"/users/log-in")

    {:ok, _lv, html} =
      lv
      |> form("#login_form_magic", user: %{email: unknown})
      |> render_submit()
      |> follow_redirect(conn, ~p"/users/log-in")

    assert html =~ "Too many login requests"
  end

  test "password attempts for one account are capped independent of IP", %{conn: conn} do
    user = set_password(user_fixture())

    for _ <- 1..10 do
      conn =
        post(conn, ~p"/users/log-in", %{
          "user" => %{"email" => user.email, "password" => "wrong password"}
        })

      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "Invalid email or password"
    end

    # Even the correct password is refused once the budget is spent
    conn =
      post(conn, ~p"/users/log-in", %{
        "user" => %{"email" => user.email, "password" => valid_user_password()}
      })

    assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "Too many login attempts"
    refute get_session(conn, :user_token)
  end

  test "the login POST endpoint is throttled per client IP", %{conn: conn} do
    for _ <- 1..20 do
      conn =
        post(conn, ~p"/users/log-in", %{
          "user" => %{"email" => unique_user_email(), "password" => "x"}
        })

      assert redirected_to(conn) == ~p"/users/log-in"
    end

    conn =
      post(conn, ~p"/users/log-in", %{
        "user" => %{"email" => unique_user_email(), "password" => "x"}
      })

    assert conn.status == 429
    assert get_resp_header(conn, "retry-after") != []
  end
end
