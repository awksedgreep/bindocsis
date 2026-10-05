defmodule BindocsisWeb.Plugs.RateLimit do
  @moduledoc """
  Per-client-IP request throttle (issue #13).

      plug BindocsisWeb.Plugs.RateLimit, scope: :login, limit: 10, window: :timer.minutes(1)

  Over the limit the request is answered with 429 and halted.

  ## Client IP behind a proxy

  Behind Fly / a reverse proxy `conn.remote_ip` is the proxy, so every user
  would share one bucket. `client_ip/1` therefore prefers, in order:

  1. `fly-client-ip` (set by the Fly proxy),
  2. the *last* entry of `x-forwarded-for` (the address appended by the
     nearest proxy; earlier entries are client-supplied),
  3. `conn.remote_ip`.

  A client talking to the app directly can forge these headers and so dodge
  the per-IP limit; the per-account / per-email limits in the session
  controller and login LiveView do not depend on the IP and still hold.
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

  @doc "Client IP as a string, for use as a rate-limit key (see module doc)."
  def client_ip(%Plug.Conn{remote_ip: ip} = conn) do
    forwarded_ip(get_req_header(conn, "fly-client-ip"), get_req_header(conn, "x-forwarded-for")) ||
      format_ip(ip)
  end

  @doc """
  Same for a LiveView socket (needs `:peer_data` and `:x_headers` in
  `connect_info`).
  """
  def socket_ip(socket) do
    x_headers = Phoenix.LiveView.get_connect_info(socket, :x_headers) || []
    fly = for {"fly-client-ip", v} <- x_headers, do: v
    xff = for {"x-forwarded-for", v} <- x_headers, do: v

    forwarded_ip(fly, xff) ||
      case Phoenix.LiveView.get_connect_info(socket, :peer_data) do
        %{address: ip} -> format_ip(ip)
        _ -> "unknown"
      end
  end

  @doc false
  def forwarded_ip([fly | _], _xff) when is_binary(fly) and fly != "", do: String.trim(fly)

  def forwarded_ip(_fly, [xff | _]) when is_binary(xff) do
    xff
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
    |> List.last()
  end

  def forwarded_ip(_, _), do: nil

  defp format_ip(ip) when is_tuple(ip), do: ip |> :inet.ntoa() |> to_string()
  defp format_ip(_), do: "unknown"
end
