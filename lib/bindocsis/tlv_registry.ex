defmodule Bindocsis.TlvRegistry do
  @moduledoc """
  Machine-readable registry of every TLV path this library understands.

  The registry is the enforcement layer of issue #4: one row per TLV path
  (e.g. `"202.2.2"`), each carrying the resolved name, value type, and the
  spec citation extracted from its description. Rows whose descriptions carry
  no recognizable citation are marked `"UNVERIFIED"` - visible debt that may
  only shrink (see test/tlv_registry_test.exs).

  The canonical snapshot lives at `priv/tlv_registry.json` and is kept in
  sync with `Bindocsis.DocsisSpecs` / `Bindocsis.SubTlvSpecs` by a test that
  rebuilds the registry from the modules and diffs it against the file.
  Regenerate after intentional spec changes with:

      mix run -e "Bindocsis.TlvRegistry.write!()"
  """

  alias Bindocsis.{DocsisSpecs, SubTlvSpecs}

  @registry_path "priv/tlv_registry.json"
  @max_depth 6

  # Citation fragments recognized in descriptions. Kept deliberately strict:
  # a row is only "cited" when its description names a spec document/section.
  @citation_regex ~r/(CM-SP-[A-Za-z0-9.\-]+|CL-SP-CANN[^)]*|CANN[- ]?[I0-9.]*\s*1?1?\.?[0-9.]*|MULPI[A-Za-z0-9v.\- ]*(?:Annex\s+)?[A-Z]?\.?[0-9.]*|DEMARCv[0-9.]+[^)]*|ETSI\s+E[NS]\s+[0-9 ]+[^)]*|Annex\s+[A-Z][0-9.]*[^)]*|\b[BC]\.[0-9]+(?:\.[0-9]+)+)/

  @doc """
  Builds the registry from the live spec modules.

  Returns a map of path string => row, where a row is
  `%{name, value_type, ref}` (all strings; ref is `"UNVERIFIED"` when the
  description carries no recognizable citation).
  """
  @spec build() :: %{String.t() => map()}
  def build do
    top_level_rows() |> Map.merge(subtlv_rows())
  end

  @doc "Loads the committed registry snapshot from priv/tlv_registry.json."
  @spec load() :: %{String.t() => map()}
  def load do
    Application.app_dir(:bindocsis, "priv/tlv_registry.json")
    |> File.read!()
    |> JSON.decode!()
  rescue
    # Fall back to the repo-relative path (dev/test without app_dir)
    _ -> File.read!(@registry_path) |> JSON.decode!()
  end

  @doc "Regenerates priv/tlv_registry.json from the live spec modules."
  @spec write!() :: :ok
  def write! do
    json =
      build()
      |> Enum.sort_by(fn {path, _} ->
        path |> String.split(".") |> Enum.map(&String.to_integer/1)
      end)
      |> Enum.map(fn {path, row} ->
        ~s(  "#{path}": {"name": #{JSON.encode!(row["name"])}, "value_type": #{JSON.encode!(row["value_type"])}, "ref": #{JSON.encode!(row["ref"])}})
      end)
      |> Enum.join(",\n")

    File.write!(@registry_path, "{\n" <> json <> "\n}\n")
    :ok
  end

  @doc "Paths whose rows carry no spec citation."
  @spec unverified_paths(%{String.t() => map()}) :: [String.t()]
  def unverified_paths(registry \\ build()) do
    for {path, %{"ref" => "UNVERIFIED"}} <- registry, do: path
  end

  ## Builders

  defp top_level_rows do
    for type <- 0..255,
        {:ok, info} <- [DocsisSpecs.get_tlv_info(type, "4.0")],
        into: %{} do
      path = Integer.to_string(type)
      {path, row(path, info.name, info.value_type, info.description)}
    end
  end

  defp subtlv_rows do
    Enum.reduce(0..255, %{}, fn type, acc ->
      case DocsisSpecs.get_tlv_info(type, "4.0") do
        {:ok, %{subtlv_support: true}} -> collect_subtlvs([type], acc, @max_depth)
        _ -> acc
      end
    end)
  end

  defp collect_subtlvs(_path, acc, 0), do: acc

  defp collect_subtlvs(path, acc, depth) do
    case SubTlvSpecs.get_subtlv_specs(path) do
      {:ok, specs} ->
        Enum.reduce(specs, acc, fn {sub_type, spec}, acc ->
          sub_path = path ++ [sub_type]
          key = Enum.join(sub_path, ".")
          acc = Map.put(acc, key, row(key, spec.name, spec.value_type, spec.description))

          if spec.value_type == :compound do
            collect_subtlvs(sub_path, acc, depth - 1)
          else
            acc
          end
        end)

      _ ->
        acc
    end
  end

  # Citations verified during the issue #4 audit for entries whose
  # descriptions don't carry an inline citation. Only add rows here after
  # actually diffing them against the named document - never to make the
  # unverified count look better.
  #
  # - Top-level types 0-99, 201-221, 255 were diffed entry-by-entry against
  #   the CL-SP-CANN section 11.1 registry (fabricated entries were removed
  #   in the same audit).
  # - The 202 subtree was transcribed from CM-SP-eRouter Annex B.4 (via the
  #   ETSI ES 203 386 transposition) and matches CL-SP-CANN 11.1.9.
  defp audit_overlay_ref(path) do
    [top | _] = String.split(path, ".")
    top = String.to_integer(top)

    cond do
      top == 202 -> "CM-SP-eRouter Annex B.4; CL-SP-CANN 11.1.9"
      String.contains?(path, ".") -> nil
      top in 0..99 or top in 201..221 or top == 255 -> "CL-SP-CANN 11.1"
      true -> nil
    end
  end

  defp row(path, name, value_type, description) do
    ref =
      case extract_ref(description) do
        "UNVERIFIED" -> audit_overlay_ref(path) || "UNVERIFIED"
        inline -> inline
      end

    %{
      "name" => name,
      "value_type" => Atom.to_string(value_type),
      "ref" => ref
    }
  end

  defp extract_ref(description) when is_binary(description) do
    case Regex.run(@citation_regex, description) do
      [ref | _] -> String.trim(ref)
      nil -> "UNVERIFIED"
    end
  end

  defp extract_ref(_), do: "UNVERIFIED"
end
