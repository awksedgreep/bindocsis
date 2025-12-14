defmodule BindocsisWeb.Supervisor do
  @moduledoc """
  Supervisor for BindocsisWeb processes.

  This supervisor manages:
  - `BindocsisWeb.ConfigStore` - ETS-based config storage

  ## Usage

  ### In a Phoenix Application

  Add to your application's supervision tree in `application.ex`:

      def start(_type, _args) do
        children = [
          # ... your other children
          BindocsisWeb.Supervisor
        ]

        opts = [strategy: :one_for_one, name: MyApp.Supervisor]
        Supervisor.start_link(children, opts)
      end

  ### Standalone Usage

  You can also start it manually:

      {:ok, _pid} = BindocsisWeb.Supervisor.start_link()

  ## Configuration

  The supervisor accepts the following options (passed through to ConfigStore):

  - `:ttl` - Time-to-live for configs in milliseconds (default: 24 hours)
  - `:cleanup_interval` - How often to run cleanup (default: 5 minutes)

  Example:

      BindocsisWeb.Supervisor.start_link(ttl: :timer.hours(1))
  """

  use Supervisor

  def start_link(opts \\ []) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(opts) do
    children = [
      # PubSub for LiveView
      {Phoenix.PubSub, name: Bindocsis.PubSub},
      # Config storage
      {BindocsisWeb.ConfigStore, opts},
      # Web endpoint
      BindocsisWeb.Endpoint
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  @doc """
  Checks if the BindocsisWeb services are running.

  Returns `true` if the ConfigStore is available.
  """
  def running? do
    case Process.whereis(BindocsisWeb.ConfigStore) do
      nil -> false
      pid -> Process.alive?(pid)
    end
  end

  @doc """
  Ensures the BindocsisWeb supervisor is started.

  This is useful for standalone mode or when integrating into
  applications that may not have started the supervisor yet.

  Returns `:ok` if already running, or `{:ok, pid}` if started.
  """
  def ensure_started(opts \\ []) do
    case Process.whereis(__MODULE__) do
      nil ->
        start_link(opts)

      pid ->
        {:ok, pid}
    end
  end
end
