defmodule BindocsisWeb.Params do
  @moduledoc """
  Safe decoding of user-controlled LiveView parameters.

  Everything that arrives through URL params or `phx-value-*` attributes is
  attacker-controlled. `String.to_integer/1` raises on `"abc"` (crashing the
  LiveView into a reconnect loop) and `String.to_atom/1` grows the atom table
  without bound. Every call site goes through this module instead, and
  returns a tagged result the caller can ignore or turn into a flash.
  """

  @view_modes %{"tree" => :tree, "table" => :table, "hex" => :hex}

  @doc "Whitelisted viewer modes; anything else is `nil`."
  @spec view_mode(term()) :: :tree | :table | :hex | nil
  def view_mode(mode) when is_binary(mode), do: Map.get(@view_modes, mode)
  def view_mode(_), do: nil

  @doc "Parses a non-negative integer index such as `\"3\"`."
  @spec index(term()) :: {:ok, non_neg_integer()} | :error
  def index(str) when is_binary(str) do
    case Integer.parse(str) do
      {n, ""} when n >= 0 -> {:ok, n}
      _ -> :error
    end
  end

  def index(_), do: :error

  @doc "Parses a TLV type number (0-255)."
  @spec tlv_type(term()) :: {:ok, 0..255} | :error
  def tlv_type(str) do
    case index(str) do
      {:ok, n} when n <= 255 -> {:ok, n}
      _ -> :error
    end
  end

  @doc """
  Parses an optional TLV type: `nil` / `\"\"` mean "absent" and yield
  `{:ok, nil}`; any other value must be a valid type number.
  """
  @spec optional_tlv_type(term()) :: {:ok, 0..255 | nil} | :error
  def optional_tlv_type(nil), do: {:ok, nil}
  def optional_tlv_type(""), do: {:ok, nil}
  def optional_tlv_type(str), do: tlv_type(str)

  @doc """
  Parses a dotted tree path such as `\"0.2.1\"` into a list of indices.
  """
  @spec path(term()) :: {:ok, [non_neg_integer(), ...]} | :error
  def path(str) when is_binary(str) and str != "" do
    str
    |> String.split(".")
    |> Enum.reduce_while({:ok, []}, fn seg, {:ok, acc} ->
      case index(seg) do
        {:ok, n} -> {:cont, {:ok, [n | acc]}}
        :error -> {:halt, :error}
      end
    end)
    |> case do
      {:ok, rev} -> {:ok, Enum.reverse(rev)}
      :error -> :error
    end
  end

  def path(_), do: :error
end
