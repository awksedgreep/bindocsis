defmodule BindocsisWeb.ConfigStore do
  @moduledoc """
  Temporary storage for parsed DOCSIS config files.

  Uses ETS for fast access with automatic cleanup after TTL expires.
  This allows configs to persist across LiveView reconnects while
  automatically cleaning up old entries.

  ## Storage Format

  Each config entry contains:
  - `id` - UUID identifier
  - `name` - Original filename
  - `raw_bytes` - Original binary data
  - `parsed` - List of parsed TLV structs
  - `enriched` - Enriched TLVs with metadata
  - `modified` - Whether the config has unsaved changes
  - `created_at` - When the config was uploaded
  - `updated_at` - Last modification time
  - `expires_at` - When to auto-delete

  ## Limits

  The store is an in-memory cache, so it is bounded (issue #12):

  - `:max_upload_bytes` - largest accepted `raw_bytes` (default 1 MB)
  - `:max_entries` - total configs kept (default 200); the least recently
    used entries are evicted when exceeded
  - `:max_bytes` - total `raw_bytes` kept (default 64 MB); LRU eviction
  - `:max_per_owner` - configs one owner may hold (default 50); further
    stores return `{:error, :quota_exceeded}`

  Configs that fail to parse are rejected with `{:error, {:parse_failed,
  reason}}` rather than stored as empty entries.

  ## Usage

      # Store a new config
      {:ok, id} = ConfigStore.store(raw_bytes, name: "config.cm", owner: user_id)

      # Retrieve a config
      {:ok, config} = ConfigStore.get(id)

      # Update after editing
      :ok = ConfigStore.update(id, %{parsed: new_tlvs, modified: true})

      # List all configs
      configs = ConfigStore.list_all()

      # Delete a config
      :ok = ConfigStore.delete(id)
  """

  use GenServer

  require Logger

  @table :bindocsis_configs
  @default_ttl :timer.hours(24)
  @cleanup_interval :timer.minutes(5)

  @default_limits %{
    max_upload_bytes: 1_000_000,
    max_entries: 200,
    max_bytes: 64 * 1024 * 1024,
    max_per_owner: 50
  }

  # ============================================================================
  # Client API
  # ============================================================================

  @doc """
  Starts the ConfigStore GenServer.

  ## Options

  - `:ttl` - Time-to-live for configs in milliseconds (default: 24 hours)
  - `:cleanup_interval` - How often to run cleanup in milliseconds (default: 5 minutes)
  - `:max_upload_bytes`, `:max_entries`, `:max_bytes`, `:max_per_owner` -
    see the module documentation
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Stores a new config and returns its UUID.

  ## Options

  - `:name` - Original filename (default: "untitled.cm")
  - `:ttl` - Override default TTL for this config
  - `:owner` - Opaque owner id (e.g. user id) used for the per-owner quota
  - `:format` - Explicit input format; otherwise detected from the name

  Returns `{:ok, id}`, or `{:error, reason}` with reason one of
  `:too_large`, `:quota_exceeded`, `{:parse_failed, message}`.

  ## Examples

      {:ok, id} = ConfigStore.store(binary_data, name: "my_config.cm")
  """
  def store(raw_bytes, opts \\ []) when is_binary(raw_bytes) do
    GenServer.call(__MODULE__, {:store, raw_bytes, opts})
  end

  @doc """
  Returns the active limits map (see module documentation).
  """
  def limits do
    GenServer.call(__MODULE__, :limits)
  end

  @doc """
  Overrides limits at runtime; unspecified keys keep their current value.
  Intended for tests and operators tuning a running node.
  """
  def set_limits(overrides) when is_list(overrides) or is_map(overrides) do
    GenServer.call(__MODULE__, {:set_limits, Map.new(overrides)})
  end

  @doc """
  Retrieves a config by ID.

  Returns `{:ok, config}` or `{:error, :not_found}`.
  """
  def get(id) when is_binary(id) do
    case :ets.lookup(@table, id) do
      [{^id, config}] ->
        # Update last accessed time (touch)
        GenServer.cast(__MODULE__, {:touch, id})
        {:ok, config}

      [] ->
        {:error, :not_found}
    end
  end

  @doc """
  Updates a config's fields.

  Accepts a map with any of: `:parsed`, `:enriched`, `:modified`, `:name`.
  Automatically updates `:updated_at`.

  ## Examples

      :ok = ConfigStore.update(id, %{parsed: new_tlvs, modified: true})
  """
  def update(id, changes) when is_binary(id) and is_map(changes) do
    GenServer.call(__MODULE__, {:update, id, changes})
  end

  @doc """
  Deletes a config by ID.
  """
  def delete(id) when is_binary(id) do
    GenServer.call(__MODULE__, {:delete, id})
  end

  @doc """
  Lists all stored configs.

  Returns a list of config maps, sorted by `updated_at` descending (most recent first).
  """
  def list_all do
    @table
    |> :ets.tab2list()
    |> Enum.map(fn {_id, config} -> config end)
    |> Enum.sort_by(& &1.updated_at, {:desc, DateTime})
  end

  @doc """
  Total bytes of `raw_bytes` currently held.
  """
  def total_bytes do
    :ets.foldl(fn {_id, config}, acc -> acc + byte_size(config.raw_bytes) end, 0, @table)
  end

  @doc """
  Returns the count of stored configs.
  """
  def count do
    :ets.info(@table, :size)
  end

  @doc """
  Checks if a config exists.
  """
  def exists?(id) when is_binary(id) do
    :ets.member(@table, id)
  end

  @doc """
  Extends the TTL of a config.

  Useful when a user is actively working on a config.
  """
  def extend_ttl(id, ttl \\ @default_ttl) when is_binary(id) do
    GenServer.call(__MODULE__, {:extend_ttl, id, ttl})
  end

  # ============================================================================
  # Server Callbacks
  # ============================================================================

  @impl true
  def init(opts) do
    # Create ETS table
    table = :ets.new(@table, [:named_table, :set, :public, read_concurrency: true])

    ttl = Keyword.get(opts, :ttl, @default_ttl)
    cleanup_interval = Keyword.get(opts, :cleanup_interval, @cleanup_interval)

    limits =
      @default_limits
      |> Map.merge(Map.new(Application.get_env(:bindocsis, __MODULE__, [])))
      |> Map.merge(opts |> Keyword.take(Map.keys(@default_limits)) |> Map.new())

    # Schedule first cleanup
    Process.send_after(self(), :cleanup, cleanup_interval)

    {:ok, %{table: table, ttl: ttl, cleanup_interval: cleanup_interval, limits: limits}}
  end

  @impl true
  def handle_call(:limits, _from, state), do: {:reply, state.limits, state}

  @impl true
  def handle_call({:set_limits, overrides}, _from, state) do
    limits = Map.merge(state.limits, Map.take(overrides, Map.keys(@default_limits)))
    {:reply, :ok, %{state | limits: limits}}
  end

  @impl true
  def handle_call({:store, raw_bytes, opts}, _from, state) do
    name = Keyword.get(opts, :name, "untitled.cm")
    owner = Keyword.get(opts, :owner)
    limits = state.limits

    with :ok <- check_size(raw_bytes, limits),
         :ok <- check_owner_quota(owner, limits),
         {:ok, parsed} <-
           parse_config(raw_bytes, Keyword.get(opts, :format) || detect_format(name)) do
      id = generate_id()
      ttl = Keyword.get(opts, :ttl, state.ttl)
      now = DateTime.utc_now()

      config = %{
        id: id,
        name: name,
        owner: owner,
        raw_bytes: raw_bytes,
        parsed: parsed,
        enriched: parsed,
        modified: false,
        created_at: now,
        updated_at: now,
        expires_at: DateTime.add(now, ttl, :millisecond)
      }

      :ets.insert(@table, {id, config})
      evict_over_limits(id, limits)

      Logger.debug("ConfigStore: Stored config #{id} (#{name}, #{byte_size(raw_bytes)} bytes)")

      {:reply, {:ok, id}, state}
    else
      {:error, reason} -> {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:update, id, changes}, _from, state) do
    case :ets.lookup(@table, id) do
      [{^id, config}] ->
        allowed_keys = [:parsed, :enriched, :modified, :name, :raw_bytes]
        filtered_changes = Map.take(changes, allowed_keys)

        updated_config =
          config
          |> Map.merge(filtered_changes)
          |> Map.put(:updated_at, DateTime.utc_now())

        :ets.insert(@table, {id, updated_config})
        {:reply, :ok, state}

      [] ->
        {:reply, {:error, :not_found}, state}
    end
  end

  @impl true
  def handle_call({:delete, id}, _from, state) do
    :ets.delete(@table, id)
    Logger.debug("ConfigStore: Deleted config #{id}")
    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:extend_ttl, id, ttl}, _from, state) do
    case :ets.lookup(@table, id) do
      [{^id, config}] ->
        now = DateTime.utc_now()

        updated_config = %{
          config
          | expires_at: DateTime.add(now, ttl, :millisecond),
            updated_at: now
        }

        :ets.insert(@table, {id, updated_config})
        {:reply, :ok, state}

      [] ->
        {:reply, {:error, :not_found}, state}
    end
  end

  @impl true
  def handle_cast({:touch, id}, state) do
    case :ets.lookup(@table, id) do
      [{^id, config}] ->
        updated_config = %{config | updated_at: DateTime.utc_now()}
        :ets.insert(@table, {id, updated_config})

      [] ->
        :ok
    end

    {:noreply, state}
  end

  @impl true
  def handle_info(:cleanup, state) do
    now = DateTime.utc_now()

    expired =
      @table
      |> :ets.tab2list()
      |> Enum.filter(fn {_id, config} ->
        DateTime.compare(config.expires_at, now) == :lt
      end)

    Enum.each(expired, fn {id, config} ->
      :ets.delete(@table, id)
      Logger.debug("ConfigStore: Expired config #{id} (#{config.name})")
    end)

    if length(expired) > 0 do
      Logger.info("ConfigStore: Cleaned up #{length(expired)} expired configs")
    end

    # Schedule next cleanup
    Process.send_after(self(), :cleanup, state.cleanup_interval)

    {:noreply, state}
  end

  # ============================================================================
  # Private Functions
  # ============================================================================

  defp generate_id do
    :crypto.strong_rand_bytes(16)
    |> Base.url_encode64(padding: false)
  end

  defp parse_config(raw_bytes, format) do
    case Bindocsis.parse(raw_bytes, format: format, enhanced: true) do
      {:ok, parsed} ->
        # The enriched data is already included when enhanced: true
        {:ok, parsed}

      {:error, reason} ->
        Logger.warning(
          "ConfigStore: Failed to parse config (format: #{format}): #{inspect(reason)}"
        )

        {:error, {:parse_failed, to_string_reason(reason)}}
    end
  end

  defp to_string_reason(reason) when is_binary(reason), do: reason
  defp to_string_reason(reason), do: inspect(reason)

  defp check_size(raw_bytes, %{max_upload_bytes: max}) do
    if byte_size(raw_bytes) > max, do: {:error, :too_large}, else: :ok
  end

  defp check_owner_quota(nil, _limits), do: :ok

  defp check_owner_quota(owner, %{max_per_owner: max}) do
    owned =
      :ets.foldl(
        fn {_id, config}, acc -> if config.owner == owner, do: acc + 1, else: acc end,
        0,
        @table
      )

    if owned >= max, do: {:error, :quota_exceeded}, else: :ok
  end

  # Drop least-recently-used entries (never the one just stored) until both
  # the entry count and the byte total are within limits.
  defp evict_over_limits(keep_id, %{max_entries: max_entries, max_bytes: max_bytes}) do
    entries = :ets.tab2list(@table)
    count = length(entries)
    bytes = Enum.reduce(entries, 0, fn {_id, c}, acc -> acc + byte_size(c.raw_bytes) end)

    if count > max_entries or bytes > max_bytes do
      entries
      |> Enum.reject(fn {id, _} -> id == keep_id end)
      |> Enum.sort_by(fn {_id, c} -> c.updated_at end, {:asc, DateTime})
      |> Enum.reduce_while({count, bytes}, fn {id, config}, {count, bytes} ->
        if count > max_entries or bytes > max_bytes do
          :ets.delete(@table, id)
          Logger.info("ConfigStore: Evicted #{id} (#{config.name}) to stay within limits")
          {:cont, {count - 1, bytes - byte_size(config.raw_bytes)}}
        else
          {:halt, {count, bytes}}
        end
      end)
    end

    :ok
  end

  @doc """
  Detects the format of a config file based on filename extension.

  Returns `:binary`, `:json`, `:yaml`, or `:config`.
  """
  def detect_format(filename) when is_binary(filename) do
    filename
    |> String.downcase()
    |> Path.extname()
    |> case do
      ".json" -> :json
      ".yaml" -> :yaml
      ".yml" -> :yaml
      ".txt" -> :config
      ".cfg" -> :config
      ".conf" -> :config
      _ -> :binary
    end
  end

  def detect_format(_), do: :binary
end
