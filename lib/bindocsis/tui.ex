defmodule Bindocsis.Tui do
  @moduledoc """
  Entry point for the `bindocsis tui` full-screen config browser.

  Loads a config file through the standard pipeline
  (`Bindocsis.parse_file/2` → `TlvEnricher` → `ConfigValidator`),
  then serves it in an ExRatatui terminal UI (`Bindocsis.Tui.App`).

  The TUI needs a real terminal and the ExRatatui NIF (available in
  `mix` runs and OTP releases, not in escript builds). Both are checked
  up front with actionable errors; use the classic `parse`/`validate`
  CLI commands (or the web UI) where a TUI cannot run.
  """

  alias Bindocsis.Tui.{App, State}

  @doc """
  Runs the TUI browser for `path`.

  Options:

    - `:docsis_version` — version string for validation (default `"3.1"`)
    - `:force` — skip the TTY check (piped output, tests)
    - `:validate` — run `ConfigValidator` (default `true`; pass `false`
      to open files that fail validation hard)
    - `:shared_secret` — secret for CMTS MIC (TLV 7) recomputation on
      save; defaults to the `BINDOCSIS_SHARED_SECRET` env var

  Returns `:ok` on clean quit or `{:error, reason}`.
  """
  @spec run(String.t(), keyword()) :: :ok | {:error, String.t()}
  def run(path, opts \\ []) do
    with :ok <- check_tty(opts),
         :ok <- check_runtime(),
         {:ok, loaded} <- load_file(path, opts) do
      start_and_wait(State.load(loaded))
    end
  end

  @doc "True when stdout looks like an interactive terminal."
  @spec tty?() :: boolean()
  def tty? do
    match?({:ok, _}, :io.columns())
  end

  # -- internals --------------------------------------------------------

  defp check_tty(opts) do
    if Keyword.get(opts, :force, false) or tty?() do
      :ok
    else
      {:error,
       "No interactive terminal detected (stdout is not a TTY). " <>
         "Use `bindocsis parse --input FILE` or `bindocsis validate --input FILE` instead."}
    end
  end

  # The NIF loads lazily; probe it before taking over the terminal so
  # escript builds (which cannot bundle the .so) fail with guidance.
  defp check_runtime do
    ExRatatui.init_test_terminal(8, 2)
    :ok
  rescue
    e ->
      {:error,
       "Terminal UI runtime unavailable (#{Exception.message(e)}). " <>
         "The TUI needs the ExRatatui NIF: run from `mix` or an OTP release, not the escript build."}
  end

  defp load_file(path, opts) do
    version = Keyword.get(opts, :docsis_version, "3.1")
    do_validate = Keyword.get(opts, :validate, true)

    with {:ok, file_binary} <- File.read(path),
         {:ok, tlvs} <- Bindocsis.parse_file(path) do
      enriched = Bindocsis.TlvEnricher.enrich_tlvs(tlvs)

      validation =
        if do_validate do
          case Bindocsis.ConfigValidator.validate(file_binary, docsis_version: version) do
            {:ok, result} -> result
            {:error, _} -> nil
          end
        else
          nil
        end

      {:ok,
       %{
         path: path,
         file_size: byte_size(file_binary),
         tlvs: enriched,
         raw_binary: file_binary,
         validation: validation,
         shared_secret:
           Keyword.get(opts, :shared_secret, System.get_env("BINDOCSIS_SHARED_SECRET")),
         docsis_version: version
       }}
    else
      {:error, reason} ->
        message = if is_binary(reason), do: reason, else: inspect(reason)
        {:error, message}
    end
  end

  defp start_and_wait(state) do
    case App.start_link(state: state, name: nil) do
      {:ok, pid} ->
        ref = Process.monitor(pid)

        receive do
          {:DOWN, ^ref, :process, ^pid, _reason} -> :ok
        end

      {:error, reason} ->
        {:error, "Failed to start TUI: #{inspect(reason)}"}
    end
  end
end
