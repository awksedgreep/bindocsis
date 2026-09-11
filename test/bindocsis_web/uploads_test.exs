defmodule BindocsisWeb.UploadsTest do
  use ExUnit.Case, async: false

  alias BindocsisWeb.{ConfigStore, Uploads}

  @tmp Path.join(System.tmp_dir!(), "bindocsis_uploads_test")

  setup do
    File.mkdir_p!(@tmp)
    ids_before = ConfigStore.list_all() |> Enum.map(& &1.id) |> MapSet.new()

    on_exit(fn ->
      File.rm_rf!(@tmp)

      ConfigStore.list_all()
      |> Enum.reject(&MapSet.member?(ids_before, &1.id))
      |> Enum.each(&ConfigStore.delete(&1.id))
    end)

    :ok
  end

  test "accepted_name?/1 is case-insensitive on the extension only" do
    assert Uploads.accepted_name?("modem.cm")
    assert Uploads.accepted_name?("MODEM.CM")
    assert Uploads.accepted_name?("cfg.yaml")
    refute Uploads.accepted_name?("modem.exe")
    refute Uploads.accepted_name?("modem")
    refute Uploads.accepted_name?(nil)
  end

  test "store_entry/3 rejects a disallowed client name before reading the file (issue #12)" do
    path = Path.join(@tmp, "x")
    File.write!(path, <<3, 1, 1, 0xFF>>)

    assert {:error, msg} = Uploads.store_entry(path, %{client_name: "evil.exe"})
    assert msg =~ "evil.exe"
    assert msg =~ "invalid file type"
  end

  test "store_entry/3 reports a missing temp file instead of raising (issue #12)" do
    path = Path.join(@tmp, "gone")
    refute File.exists?(path)

    assert {:error, msg} = Uploads.store_entry(path, %{client_name: "ok.cm"})
    assert msg =~ "cancelled or expired"
  end

  test "store_entry/3 stores a valid file with its owner" do
    path = Path.join(@tmp, "good")
    File.write!(path, <<3, 1, 1, 0xFF>>)

    assert {:ok, id} = Uploads.store_entry(path, %{client_name: "good.cm"}, owner: :me)
    assert {:ok, %{owner: :me, name: "good.cm"}} = ConfigStore.get(id)
  end
end
