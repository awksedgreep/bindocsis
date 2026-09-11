defmodule BindocsisWeb.Plugs.RateLimit do
  @moduledoc """
  Per-client-IP request throttle (issue #13).

      plug BindocsisWeb.Plugs.RateLimit, scope: :login, limit: 10, window: :timer.minutes(1)

  Over the limit the request is answered with 429 and halted. The IP is
  `conn.remote_ip`; behind Fly / a reverse proxy that is the proxy unless
  a `RemoteIp`-style plug rewrote it, so per-IP limits are best-effort
  there. The per-account limits in the session controller and login
  LiveView do not depend on the IP.
  """

  import Plug.Conn

  alias BindocsisWeb.RateLimiter

  def init(opts) do
    %{
      scope: Keyword.fetch!(opts, :scope),
      limit: Keyword.fetch!(opts, :limit),
      window: Keyword.fetch!(opts, :window)
    }
  end

  def call(conn, %{scope: scope, limit: limit, window: window}) do
    case RateLimiter.check({scope, client_ip(conn)}, limit, window) do
      :ok ->
        conn

      {:error, retry_ms} ->
        conn
        |> put_resp_header("retry-after", Integer.to_string(max(div(retry_ms, 1000), 1)))
        |> send_resp(429, "Too many requests. Please try again later.")
        |> halt()
    end
  end

  @doc "Client IP as a string, for use as a rate-limit key."
  def client_ip(%Plug.Conn{remote_ip: ip}), do: format_ip(ip)

  @doc "Same for a LiveView socket (needs `:peer_data` in `connect_info`)."
  def socket_ip(socket) do
    case Phoenix.LiveView.get_connect_info(socket, :peer_data) do
      %{address: ip} -> format_ip(ip)
      _ -> "unknown"
    end
  end

  defp format_ip(ip) when is_tuple(ip), do: ip |> :inet.ntoa() |> to_string()
  defp format_ip(_), do: "unknown"
end
