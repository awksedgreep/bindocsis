defmodule BindocsisWeb.Uploads do
  @moduledoc """
  Shared upload policy for the dashboard and config-list LiveViews.

  Centralises the accepted file extensions (enforced both by
  `allow_upload/3` and again server-side on `entry.client_name`), the
  per-file size limit, and the consume step that turns a temp file into a
  `BindocsisWeb.ConfigStore` entry without ever raising into the LiveView.
  """

  alias BindocsisWeb.ConfigStore

  @accepted_extensions ~w(.cm .bin .json .yaml .yml .cfg .conf .txt)
  @max_file_size 1_000_000

  @doc "Extensions accepted by the upload widgets (lower-case, with dot)."
  def accepted_extensions, do: @accepted_extensions

  @doc "Per-file upload limit in bytes."
  def max_file_size, do: @max_file_size

  @doc "Human-readable list for error messages and hints."
  def accepted_extensions_label, do: Enum.join(@accepted_extensions, ", ")

  @doc "True when the client-supplied filename has an accepted extension."
  def accepted_name?(name) when is_binary(name) do
    ext = name |> Path.extname() |> String.downcase()
    ext in @accepted_extensions
  end

  def accepted_name?(_), do: false

  @doc """
  Consume callback body: reads the temp file and stores it.

  Returns `{:ok, id}` or `{:error, message}`; never raises. A cancelled or
  expired upload leaves no temp file behind, which is the `File.read/1`
  error branch.
  """
  def store_entry(path, entry, opts \\ []) do
    name = entry.client_name

    with true <- accepted_name?(name) || {:error, :not_accepted},
         {:ok, raw_bytes} <- File.read(path),
         {:ok, id} <- ConfigStore.store(raw_bytes, Keyword.put(opts, :name, name)) do
      {:ok, id}
    else
      {:error, reason} -> {:error, "#{name}: #{error_message(reason)}"}
    end
  end

  @doc """
  Per-owner upload throttle (issue #13): 30 upload submissions per minute.
  Anonymous (embedded, unauthenticated) sessions share one bucket.
  """
  def check_rate(owner) do
    case BindocsisWeb.RateLimiter.check({:upload, owner || :anonymous}, 30, :timer.minutes(1)) do
      :ok -> :ok
      {:error, _} -> {:error, "too many uploads; please wait a minute and try again"}
    end
  end

  @doc "Maps upload / store error reasons to user-facing text."
  def error_message(:too_large),
    do: "file is too large (max #{div(@max_file_size, 1_000_000)} MB)"

  def error_message(:not_accepted),
    do: "invalid file type (use #{accepted_extensions_label()})"

  def error_message(:too_many_files), do: "too many files"
  def error_message(:quota_exceeded), do: "storage quota reached; delete some configs first"
  def error_message({:parse_failed, reason}), do: "could not parse config (#{reason})"
  def error_message(:enoent), do: "upload was cancelled or expired"
  def error_message(reason) when is_atom(reason), do: "upload error (#{reason})"
  def error_message(reason), do: "upload error (#{inspect(reason)})"
end
