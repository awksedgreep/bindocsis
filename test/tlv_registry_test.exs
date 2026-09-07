defmodule Bindocsis.TlvRegistryTest do
  use ExUnit.Case
  alias Bindocsis.TlvRegistry

  @moduledoc """
  Registry enforcement (issue #4).

  1. **Sync**: the committed priv/tlv_registry.json must exactly match the
     registry rebuilt from the live spec modules, so DocsisSpecs and
     SubTlvSpecs can never silently drift from the reviewed registry. After
     an intentional spec change, regenerate with
     `mix run -e "Bindocsis.TlvRegistry.write!()"` and review the JSON diff.

  2. **Citation ratchet**: rows without a spec citation are tracked in
     test/known_gaps/unverified_registry_paths.txt, which may only SHRINK.
     A new uncited row fails the build - cite the spec section in the
     entry's description (or, for entries verified against a document
     without editing descriptions, the audited overlay in TlvRegistry).
  """

  @unverified_snapshot "test/known_gaps/unverified_registry_paths.txt"

  test "committed registry matches the live spec modules exactly" do
    built = TlvRegistry.build()
    committed = TlvRegistry.load()

    missing = Map.keys(built) -- Map.keys(committed)
    extra = Map.keys(committed) -- Map.keys(built)

    assert missing == [], """
    Spec modules define TLV paths missing from priv/tlv_registry.json:
    #{Enum.join(Enum.sort(missing), ", ")}
    Regenerate with: mix run -e "Bindocsis.TlvRegistry.write!()" and review the diff.
    """

    assert extra == [], """
    priv/tlv_registry.json has rows the spec modules no longer define:
    #{Enum.join(Enum.sort(extra), ", ")}
    Regenerate with: mix run -e "Bindocsis.TlvRegistry.write!()" and review the diff.
    """

    changed =
      for {path, row} <- built, committed[path] != row do
        {path, committed[path], row}
      end

    assert changed == [], """
    Registry rows differ from the spec modules (path, committed, live):
    #{changed |> Enum.take(10) |> inspect(pretty: true)}
    Regenerate with: mix run -e "Bindocsis.TlvRegistry.write!()" and review the diff.
    """
  end

  test "uncited registry rows may only shrink (citation ratchet)" do
    current = MapSet.new(TlvRegistry.unverified_paths())

    snapshot =
      @unverified_snapshot
      |> File.read!()
      |> String.split("\n", trim: true)
      |> MapSet.new()

    new_uncited = MapSet.difference(current, snapshot)
    stale = MapSet.difference(snapshot, current)

    assert MapSet.size(new_uncited) == 0, """
    NEW spec entries without a citation:

    #{new_uncited |> Enum.sort() |> Enum.join("\n")}

    Every new TLV entry must cite its spec section (e.g. "MULPI C.2.1.9.1",
    "CANN 11.1.4") in its description. Do NOT add these to the snapshot.
    """

    assert MapSet.size(stale) == 0, """
    Snapshot entries that are now cited (nice!):

    #{stale |> Enum.sort() |> Enum.join("\n")}

    Delete these lines from #{@unverified_snapshot} so the ratchet tightens.
    """
  end

  test "registry rows are well-formed" do
    for {path, row} <- TlvRegistry.build() do
      assert path =~ ~r/^\d+(\.\d+)*$/, "bad path #{inspect(path)}"
      assert is_binary(row["name"]) and row["name"] != "", "row #{path} missing name"
      assert is_binary(row["value_type"]), "row #{path} missing value_type"
      assert is_binary(row["ref"]) and row["ref"] != "", "row #{path} missing ref"
    end
  end

  test "audited paths carry their citations" do
    registry = TlvRegistry.build()

    assert registry["202"]["ref"] =~ "eRouter"
    assert registry["202.2.2"]["ref"] =~ "eRouter"
    assert registry["62"]["ref"] =~ "MULPI"
    assert registry["22.9.7"]["ref"] != "UNVERIFIED"
    assert registry["43.12.1"]["ref"] =~ "DEMARC"
  end
end
