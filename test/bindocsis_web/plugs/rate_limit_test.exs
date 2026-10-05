defmodule BindocsisWeb.Plugs.RateLimitTest do
  use ExUnit.Case, async: true

  import Plug.Test
  import Plug.Conn

  alias BindocsisWeb.Plugs.RateLimit

  test "client_ip/1 falls back to remote_ip" do
    conn = %{conn(:get, "/") | remote_ip: {10, 1, 2, 3}}
    assert RateLimit.client_ip(conn) == "10.1.2.3"
  end

  test "client_ip/1 prefers fly-client-ip, then the last x-forwarded-for hop (proxy-appended)" do
    conn =
      conn(:get, "/")
      |> put_req_header("x-forwarded-for", "1.1.1.1, 203.0.113.9")

    assert RateLimit.client_ip(conn) == "203.0.113.9"

    conn = put_req_header(conn, "fly-client-ip", "198.51.100.7")
    assert RateLimit.client_ip(conn) == "198.51.100.7"
  end

  test "forwarded_ip/2 ignores blank headers" do
    assert RateLimit.forwarded_ip([""], []) == nil
    assert RateLimit.forwarded_ip([], [" , "]) == nil
  end
end
