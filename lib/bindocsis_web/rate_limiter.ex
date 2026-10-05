defmodule BindocsisWeb.RateLimiter do
  @moduledoc """
  Minimal fixed-window rate limiter on ETS (issue #13).

  `check/3` increments the counter for `key` in the current window and
  returns `:ok` while the count is within `limit`, otherwise
  `{:error, retry_after_ms}`. Windows are keyed by
  `div(now_ms, window_ms)`, so a burst can at most reach `2 * limit`
  across a window boundary; that is acceptable for login / email / upload
  throttling and keeps the implementation dependency-free.

  The owning process sweeps stale windows every minute. Keys are any
  term; callers namespace them (`{:login_ip, ip}`, `{:magic, email}`).
  """

  use GenServer

  @table :bindocsis_rate_limits
  @sweep_interval :timer.minutes(1)

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Counts one hit for `key` and checks it against `limit` per `window_ms`.
  """
  @spec check(term(), pos_integer(), pos_integer()) :: :ok | {:error, non_neg_integer()}
  def check(key, limit, window_ms) when limit > 0 and window_ms > 0 do
    now = System.system_time(:millisecond)
    bucket = div(now, window_ms)
    expires_at = (bucket + 1) * window_ms
    ets_key = {key, bucket}
    count = :ets.update_counter(@table, ets_key, {2, 1}, {ets_key, 0, expires_at})

    if count <= limit do
      :ok
    else
      {:error, expires_at - now}
    end
  rescue
    ArgumentError ->
      # Table not started (library mode / limiter not supervised): fail open
      :ok
  end

  @doc "Forgets all hits for `key` (tests, admin unblock)."
  @spec reset(term()) :: :ok
  def reset(key) do
    :ets.match_delete(@table, {{key, :_}, :_, :_})
    :ok
  rescue
    ArgumentError -> :ok
  end

  @doc "Forgets every counter."
  @spec reset_all() :: :ok
  def reset_all do
    :ets.delete_all_objects(@table)
    :ok
  rescue
    ArgumentError -> :ok
  end

  @impl true
  def init(_opts) do
    :ets.new(@table, [:named_table, :set, :public, write_concurrency: true])
    Process.send_after(self(), :sweep, @sweep_interval)
    {:ok, %{}}
  end

  @impl true
  def handle_info(:sweep, state) do
    # Every counter carries the end of its window; once that has passed the
    # counter can never be consulted again, so drop it to bound the table.
    now = System.system_time(:millisecond)
    :ets.select_delete(@table, [{{:_, :_, :"$1"}, [{:<, :"$1", now}], [true]}])

    Process.send_after(self(), :sweep, @sweep_interval)
    {:noreply, state}
  end
end
