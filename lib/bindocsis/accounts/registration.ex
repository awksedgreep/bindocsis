defmodule Bindocsis.Accounts.Registration do
  @moduledoc """
  Self-registration policy (issue #13).

  Configured under `config :bindocsis, :registration`:

  - `mode: :open` (default) - anyone may register
  - `mode: :closed` - registration disabled; existing users still log in
  - `mode: :allowlist` - only emails matching `allowlist:` may register.
    Entries are exact emails (`"ops@example.com"`) or domains
    (`"@example.com"`), compared case-insensitively.

  In production `config/runtime.exs` reads `REGISTRATION_MODE` and
  `REGISTRATION_ALLOWLIST` (comma-separated).
  """

  @type mode :: :open | :closed | :allowlist

  @spec mode() :: mode()
  def mode do
    case Keyword.get(config(), :mode, :open) do
      m when m in [:open, :closed, :allowlist] -> m
      _ -> :closed
    end
  end

  @doc "True unless registration is fully closed (links/pages are hidden then)."
  @spec enabled?() :: boolean()
  def enabled?, do: mode() != :closed

  @doc """
  Whether `email` may register under the current policy.

  Returns `:ok`, `{:error, :closed}` or `{:error, :not_allowlisted}`.
  """
  @spec check(String.t() | nil) :: :ok | {:error, :closed | :not_allowlisted}
  def check(email) do
    case mode() do
      :open -> :ok
      :closed -> {:error, :closed}
      :allowlist -> if allowlisted?(email), do: :ok, else: {:error, :not_allowlisted}
    end
  end

  @doc "Parses the comma-separated `REGISTRATION_ALLOWLIST` form."
  @spec parse_allowlist(String.t() | nil) :: [String.t()]
  def parse_allowlist(nil), do: []

  def parse_allowlist(str) when is_binary(str) do
    str
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.map(&String.downcase/1)
  end

  defp allowlisted?(email) when is_binary(email) do
    email = email |> String.trim() |> String.downcase()

    Enum.any?(allowlist(), fn
      "@" <> _ = domain -> String.ends_with?(email, domain)
      exact -> email == exact
    end)
  end

  defp allowlisted?(_), do: false

  defp allowlist do
    config() |> Keyword.get(:allowlist, []) |> Enum.map(&String.downcase/1)
  end

  defp config, do: Application.get_env(:bindocsis, :registration, [])
end
