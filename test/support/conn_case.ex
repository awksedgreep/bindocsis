defmodule BindocsisWeb.ConnCase do
  @moduledoc """
  This module defines the test case to be used by tests that require
  an HTTP connection.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      @endpoint BindocsisWeb.Endpoint
      use BindocsisWeb, :verified_routes

      import Plug.Conn
      import Phoenix.ConnTest
      import BindocsisWeb.ConnCase
      import Bindocsis.AccountsFixtures
    end
  end

  setup tags do
    Bindocsis.DataCase.setup_sandbox(tags)
    # Every test starts with a clean throttle table so per-IP limits from
    # one test never leak into the next (all ConnCase tests run sync).
    BindocsisWeb.RateLimiter.reset_all()
    :ok
  end

  setup do
    %{conn: Phoenix.ConnTest.build_conn()}
  end

  @doc """
  Logs the given `user` into the conn.

  It assigns and stores the required session data and
  rebuilds the session.
  """
  def log_in_user(conn, %Bindocsis.Accounts.User{} = user, opts \\ []) do
    token = Bindocsis.Accounts.generate_user_session_token(user)
    maybe_override_token_authenticated_at(token, opts)

    conn
    |> Phoenix.ConnTest.init_test_session(%{})
    |> Plug.Conn.put_session(:user_token, token)
  end

  defp maybe_override_token_authenticated_at(token, opts) do
    case opts do
      [token_authenticated_at: authenticated_at] ->
        Bindocsis.AccountsFixtures.override_token_authenticated_at(token, authenticated_at)

      _ ->
        :ok
    end
  end
end
