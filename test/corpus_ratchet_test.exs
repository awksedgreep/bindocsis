defmodule Bindocsis.CorpusRatchetTest do
  use ExUnit.Case

  @moduledoc """
  Coverage ratchet over the fixture corpus (issue #4).

  Two invariants, each backed by a committed snapshot in test/known_gaps/:

  1. **Nameless enrichment**: every TLV path in every fixture must enrich to a
     named, spec-backed field. Paths that currently don't are listed in
     `nameless_paths.txt`.
  2. **Round-trip fidelity**: every fixture must survive
     binary -> JSON -> binary and binary -> YAML -> binary with identical TLV
     content (trailing post-terminator padding normalized). Files that
     currently don't are listed in `roundtrip_failures.txt`.

  The snapshots may ONLY SHRINK:

  - A NEW gap (not in the snapshot) fails the build. Fix it by adding the
    missing spec / fixing the regression - never by growing the snapshot.
  - A STALE snapshot entry (gap that no longer reproduces) also fails the
    build: delete the line so the ratchet tightens permanently.
  """

  @fixtures Path.wildcard("test/fixtures/*.cm") ++ Path.wildcard("test/fixtures/*.bin")
  @nameless_snapshot "test/known_gaps/nameless_paths.txt"
  @roundtrip_snapshot "test/known_gaps/roundtrip_failures.txt"

  defp read_snapshot(path) do
    path
    |> File.read!()
    |> String.split("\n", trim: true)
    |> MapSet.new()
  end

  defp collect_nameless(tlvs, path, acc) do
    Enum.reduce(tlvs, acc, fn tlv, acc ->
      p = path ++ [tlv.type]
      name = Map.get(tlv, :name, "")

      acc =
        if Map.get(tlv, :metadata_source) == :generic_subtlv or
             String.starts_with?(name, "Sub-TLV") or
             String.starts_with?(name, "Unknown") do
          MapSet.put(acc, Enum.join(p, "."))
        else
          acc
        end

      collect_nameless(Map.get(tlv, :subtlvs) || [], p, acc)
    end)
  end

  # Strip the trailing zero padding real-world files carry after the 0xFF
  # End-of-Data marker (pad-to-4-byte-boundary), so comparison is on TLV
  # content + terminator.
  defp strip_trailing_pad(bytes) do
    size = byte_size(bytes)

    Enum.find_value((size - 1)..0//-1, bytes, fn i ->
      <<_::binary-size(i), b, rest::binary>> = bytes

      if b == 0xFF and rest == :binary.copy(<<0>>, byte_size(rest)) do
        binary_part(bytes, 0, i + 1)
      end
    end)
  end

  defp roundtrips?(bytes, fmt) do
    with {:ok, tlvs} <- Bindocsis.parse(bytes, format: :binary, enhanced: true),
         {:ok, out} <- Bindocsis.generate(tlvs, format: fmt),
         {:ok, tlvs2} <- Bindocsis.parse(out, format: fmt),
         {:ok, bin2} <- Bindocsis.generate(tlvs2, format: :binary) do
      strip_trailing_pad(bin2) == strip_trailing_pad(bytes)
    else
      _ -> false
    end
  end

  defp assert_matches_snapshot(current, snapshot_path, kind, fix_hint) do
    snapshot = read_snapshot(snapshot_path)
    new_gaps = MapSet.difference(current, snapshot)
    stale = MapSet.difference(snapshot, current)

    assert MapSet.size(new_gaps) == 0, """
    NEW #{kind} not present in #{snapshot_path}:

    #{new_gaps |> Enum.sort() |> Enum.join("\n")}

    #{fix_hint}
    Do NOT add these to the snapshot - the snapshot may only shrink.
    """

    assert MapSet.size(stale) == 0, """
    STALE entries in #{snapshot_path} - these no longer reproduce (nice!):

    #{stale |> Enum.sort() |> Enum.join("\n")}

    Delete these lines from the snapshot so the ratchet tightens.
    """
  end

  test "every TLV path in the corpus enriches to a named field (ratchet)" do
    current =
      Enum.reduce(@fixtures, MapSet.new(), fn f, acc ->
        case Bindocsis.parse(File.read!(f), format: :binary, enhanced: true) do
          {:ok, tlvs} -> collect_nameless(tlvs, [], acc)
          _ -> acc
        end
      end)

    assert_matches_snapshot(
      current,
      @nameless_snapshot,
      "nameless TLV paths",
      "Fix by adding the missing sub-TLV specs (with spec citations) to the TLV registry."
    )
  end

  test "every fixture round-trips binary -> JSON/YAML -> binary (ratchet)" do
    current =
      Enum.reduce(@fixtures, MapSet.new(), fn f, acc ->
        bytes = File.read!(f)

        if roundtrips?(bytes, :json) and roundtrips?(bytes, :yaml) do
          acc
        else
          MapSet.put(acc, Path.basename(f))
        end
      end)

    assert_matches_snapshot(
      current,
      @roundtrip_snapshot,
      "round-trip failures",
      "Fix the enrichment/generation defect that corrupts these files."
    )
  end
end
