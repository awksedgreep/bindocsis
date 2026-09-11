defmodule BindocsisWeb.ConfigStoreTest do
  use ExUnit.Case, async: false

  alias BindocsisWeb.ConfigStore

  @valid <<3, 1, 1, 0xFF>>

  setup do
    original = ConfigStore.limits()
    ids_before = ConfigStore.list_all() |> Enum.map(& &1.id) |> MapSet.new()

    on_exit(fn ->
      ConfigStore.set_limits(original)

      ConfigStore.list_all()
      |> Enum.reject(&MapSet.member?(ids_before, &1.id))
      |> Enum.each(&ConfigStore.delete(&1.id))
    end)

    :ok
  end

  test "stores and retrieves a parseable config" do
    assert {:ok, id} = ConfigStore.store(@valid, name: "a.cm", owner: :o1)
    assert {:ok, %{name: "a.cm", owner: :o1, parsed: [_]}} = ConfigStore.get(id)
  end

  test "rejects configs that do not parse instead of storing empty entries (issue #12)" do
    assert {:error, {:parse_failed, reason}} =
             ConfigStore.store("{not json", name: "bad.json")

    assert is_binary(reason)
  end

  test "rejects payloads above the upload limit" do
    ConfigStore.set_limits(max_upload_bytes: 8)
    assert {:error, :too_large} = ConfigStore.store(<<3, 1, 1, 18, 1, 5, 0, 0, 0, 0xFF>>)
  end

  test "enforces the per-owner quota" do
    ConfigStore.set_limits(max_per_owner: 2)
    assert {:ok, _} = ConfigStore.store(@valid, owner: :quota)
    assert {:ok, _} = ConfigStore.store(@valid, owner: :quota)
    assert {:error, :quota_exceeded} = ConfigStore.store(@valid, owner: :quota)
    # A different owner is unaffected
    assert {:ok, _} = ConfigStore.store(@valid, owner: :other)
  end

  test "evicts the least recently used entries when the entry cap is exceeded" do
    before = ConfigStore.count()
    ConfigStore.set_limits(max_entries: before + 2)

    {:ok, a} = ConfigStore.store(@valid, name: "a.cm")
    Process.sleep(2)
    {:ok, b} = ConfigStore.store(@valid, name: "b.cm")
    Process.sleep(2)
    # Touch a so b becomes the least recently used
    {:ok, _} = ConfigStore.get(a)
    Process.sleep(2)
    {:ok, c} = ConfigStore.store(@valid, name: "c.cm")

    assert ConfigStore.count() <= before + 2
    assert ConfigStore.exists?(c)
    refute ConfigStore.exists?(b)
  end

  test "evicts when the total byte cap is exceeded, keeping the newest" do
    ConfigStore.set_limits(max_bytes: ConfigStore.total_bytes() + 2 * byte_size(@valid))

    {:ok, a} = ConfigStore.store(@valid, name: "a.cm")
    Process.sleep(2)
    {:ok, b} = ConfigStore.store(@valid, name: "b.cm")
    Process.sleep(2)
    {:ok, c} = ConfigStore.store(@valid, name: "c.cm")

    refute ConfigStore.exists?(a)
    assert ConfigStore.exists?(b)
    assert ConfigStore.exists?(c)
  end
end
