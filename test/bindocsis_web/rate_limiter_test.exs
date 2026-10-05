defmodule BindocsisWeb.RateLimiterTest do
  use ExUnit.Case, async: false

  alias BindocsisWeb.RateLimiter

  setup do
    RateLimiter.reset_all()
    :ok
  end

  test "allows up to the limit within a window, then rejects with a retry hint" do
    key = {:test, make_ref()}

    for _ <- 1..5, do: assert(:ok = RateLimiter.check(key, 5, :timer.minutes(1)))

    assert {:error, retry_ms} = RateLimiter.check(key, 5, :timer.minutes(1))
    assert retry_ms > 0 and retry_ms <= :timer.minutes(1)
  end

  test "keys are independent" do
    a = {:test, :a}
    b = {:test, :b}

    assert {:error, _} = Enum.reduce(1..3, :ok, fn _, _ -> RateLimiter.check(a, 2, 60_000) end)
    assert :ok = RateLimiter.check(b, 2, 60_000)
  end

  test "reset/1 clears one key, reset_all/0 clears everything" do
    a = {:test, :a}
    b = {:test, :b}
    for _ <- 1..3, do: RateLimiter.check(a, 2, 60_000)
    for _ <- 1..3, do: RateLimiter.check(b, 2, 60_000)

    RateLimiter.reset(a)
    assert :ok = RateLimiter.check(a, 2, 60_000)
    assert {:error, _} = RateLimiter.check(b, 2, 60_000)

    RateLimiter.reset_all()
    assert :ok = RateLimiter.check(b, 2, 60_000)
  end

  test "a new window starts a fresh count" do
    key = {:test, :window}
    # 1 ms windows: after sleeping, the bucket has rolled over
    assert :ok = RateLimiter.check(key, 1, 1)
    assert {:error, _} = RateLimiter.check(key, 1, 1)
    Process.sleep(3)
    assert :ok = RateLimiter.check(key, 1, 1)
  end

  test "sweep removes expired counters" do
    key = {:test, :sweep}
    RateLimiter.check(key, 1, 1)
    Process.sleep(3)
    send(RateLimiter, :sweep)
    # Synchronise with the GenServer mailbox
    :sys.get_state(RateLimiter)
    assert :ets.match(:bindocsis_rate_limits, {{key, :_}, :_, :_}) == []
  end
end
