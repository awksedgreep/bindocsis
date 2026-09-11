defmodule BindocsisWeb.ParamsTest do
  use ExUnit.Case, async: true

  alias BindocsisWeb.Params

  describe "view_mode/1" do
    test "maps the three whitelisted modes" do
      assert Params.view_mode("tree") == :tree
      assert Params.view_mode("table") == :table
      assert Params.view_mode("hex") == :hex
    end

    test "rejects anything else without creating atoms" do
      assert Params.view_mode("bogus_mode_#{System.unique_integer([:positive])}") == nil
      assert Params.view_mode(nil) == nil
      assert Params.view_mode(%{}) == nil
    end
  end

  describe "index/1" do
    test "parses non-negative integers" do
      assert Params.index("0") == {:ok, 0}
      assert Params.index("42") == {:ok, 42}
    end

    test "rejects negatives, partial numbers and non-strings" do
      assert Params.index("-1") == :error
      assert Params.index("3abc") == :error
      assert Params.index("abc") == :error
      assert Params.index("") == :error
      assert Params.index(nil) == :error
      assert Params.index(3) == :error
    end
  end

  describe "tlv_type/1 and optional_tlv_type/1" do
    test "accepts 0-255 only" do
      assert Params.tlv_type("0") == {:ok, 0}
      assert Params.tlv_type("255") == {:ok, 255}
      assert Params.tlv_type("256") == :error
      assert Params.tlv_type("abc") == :error
    end

    test "optional form treats nil and empty as absent" do
      assert Params.optional_tlv_type(nil) == {:ok, nil}
      assert Params.optional_tlv_type("") == {:ok, nil}
      assert Params.optional_tlv_type("24") == {:ok, 24}
      assert Params.optional_tlv_type("x") == :error
    end
  end

  describe "path/1" do
    test "parses dotted index paths" do
      assert Params.path("0") == {:ok, [0]}
      assert Params.path("0.2.1") == {:ok, [0, 2, 1]}
    end

    test "rejects malformed paths" do
      assert Params.path("a.b") == :error
      assert Params.path("0..1") == :error
      assert Params.path("0.-1") == :error
      assert Params.path("") == :error
      assert Params.path(nil) == :error
    end
  end
end
