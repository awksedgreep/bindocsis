defmodule Bindocsis.Tui.Operations do
  @moduledoc """
  Impure file operations for the `bindocsis tui` browser: saving the
  edited config (with MIC recomputation) and exporting to other formats.

  Kept separate from `Bindocsis.Tui.State` (transitions) so the state
  layer stays free of file IO; `Bindocsis.Tui.App` calls in here on
  `s`/`X` keypresses.
  """

  alias Bindocsis.Tui.State

  @doc """
  Saves the current tree to `path` as binary.

  CM MIC (TLV 6, plain MD5) is always recomputed. CMTS MIC (TLV 7)
  needs a shared secret (`state.shared_secret`); without one an
  existing TLV 7 is dropped and the message says so — a stale MIC is
  worse than none. Returns `{:ok, new_state, message}` with the state
  reloaded from the written bytes.
  """
  @spec save(State.t(), String.t()) :: {:ok, State.t(), String.t()} | {:error, String.t()}
  def save(%{path: nil}, _path), do: {:error, "No file path to save to"}

  def save(state, path) do
    raw = state.tlvs |> Bindocsis.TlvEnricher.unenrich_tlvs() |> strip_mics()
    had_cmts_mic = had_mic?(state.tlvs, 7)

    with {:ok, cm_mic} <- Bindocsis.Crypto.MIC.compute_cm_mic(raw),
         {tlvs, mic_note} <- maybe_add_mics(raw, cm_mic, had_cmts_mic, state.shared_secret),
         {:ok, binary} <- encode_all(tlvs),
         :ok <- File.write(path, binary),
         {:ok, reloaded} <- reload_from_binary(state, binary) do
      {:ok, %{reloaded | status_msg: nil},
       "Saved #{path} (#{byte_size(binary)} bytes). #{mic_note}"}
    else
      {:error, reason} when is_binary(reason) -> {:error, reason}
      {:error, reason} -> {:error, inspect(reason)}
    end
  end

  @doc """
  Exports the current tree to `path` in `format`
  (`:binary` | `:json` | `:yaml` | `:config`). Binary export reuses the
  MIC-recomputed bytes from the save pipeline; text formats go through
  the standard generators over the enriched tree.
  """
  @spec export(State.t(), String.t(), atom()) :: {:ok, String.t()} | {:error, String.t()}
  def export(state, path, :binary) do
    case mic_recomputed_binary(state) do
      {:ok, binary, _note} ->
        case File.write(path, binary) do
          :ok -> {:ok, "Exported binary to #{path}"}
          {:error, reason} -> {:error, "Write failed: #{inspect(reason)}"}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  def export(state, path, format) when format in [:json, :yaml, :config] do
    case Bindocsis.generate(state.tlvs, format: format) do
      {:ok, content} ->
        case File.write(path, content) do
          :ok -> {:ok, "Exported #{format} to #{path}"}
          {:error, reason} -> {:error, "Write failed: #{inspect(reason)}"}
        end

      {:error, reason} ->
        {:error, "Export failed: #{inspect(reason)}"}
    end
  end

  def export(_state, _path, format), do: {:error, "Unknown export format: #{inspect(format)}"}

  # -- internals --------------------------------------------------------

  defp strip_mics(tlvs), do: Enum.reject(tlvs, &(&1.type in [6, 7]))

  defp had_mic?(tlvs, type), do: Enum.any?(tlvs, &(&1.type == type))

  defp maybe_add_mics(raw, cm_mic, had_cmts_mic, secret) do
    with_secret = raw ++ [%{type: 6, length: 16, value: cm_mic}]

    cond do
      is_binary(secret) ->
        case Bindocsis.Crypto.MIC.compute_cmts_mic(with_secret, secret) do
          {:ok, cmts_mic} ->
            {with_secret ++ [%{type: 7, length: 16, value: cmts_mic}],
             "CM MIC + CMTS MIC recomputed."}

          {:error, reason} ->
            {with_secret, "CM MIC recomputed; CMTS MIC failed (#{inspect(reason)})."}
        end

      had_cmts_mic ->
        {with_secret,
         "CM MIC recomputed; TLV 7 dropped (no shared secret — set BINDOCSIS_SHARED_SECRET)."}

      true ->
        {with_secret, "CM MIC recomputed."}
    end
  end

  defp mic_recomputed_binary(state) do
    raw = state.tlvs |> Bindocsis.TlvEnricher.unenrich_tlvs() |> strip_mics()

    with {:ok, cm_mic} <- Bindocsis.Crypto.MIC.compute_cm_mic(raw),
         {tlvs, note} <- maybe_add_mics(raw, cm_mic, had_mic?(state.tlvs, 7), state.shared_secret),
         {:ok, binary} <- encode_all(tlvs) do
      {:ok, binary, note}
    else
      {:error, reason} when is_binary(reason) -> {:error, reason}
      {:error, reason} -> {:error, inspect(reason)}
    end
  end

  defp encode_all(tlvs) do
    {:ok,
     tlvs
     |> Enum.map(&Bindocsis.Generators.BinaryGenerator.encode_single_tlv/1)
     |> IO.iodata_to_binary()}
  rescue
    e -> {:error, "Encode failed: #{Exception.message(e)}"}
  end

  # Reloads through the full pipeline so formatted values, subtlvs and
  # validation all reflect the written bytes; preserves UI expansion.
  defp reload_from_binary(state, binary) do
    validation =
      case Bindocsis.ConfigValidator.validate(binary, docsis_version: state.docsis_version) do
        {:ok, result} -> result
        {:error, _} -> nil
      end

    with {:ok, tlvs} <- Bindocsis.parse(binary) do
      enriched = Bindocsis.TlvEnricher.enrich_tlvs(tlvs)

      {:ok,
       State.reload(state, %{
         tlvs: enriched,
         raw_binary: binary,
         file_size: byte_size(binary),
         validation: validation
       })}
    else
      {:error, reason} when is_binary(reason) -> {:error, reason}
      {:error, reason} -> {:error, inspect(reason)}
    end
  end
end
