defmodule Bindocsis.Accounts.RegistrationTest do
  use Bindocsis.DataCase, async: false

  alias Bindocsis.Accounts
  alias Bindocsis.Accounts.Registration

  setup do
    original = Application.get_env(:bindocsis, :registration)
    on_exit(fn -> Application.put_env(:bindocsis, :registration, original) end)
    :ok
  end

  defp set_policy(opts), do: Application.put_env(:bindocsis, :registration, opts)

  describe "policy" do
    test "defaults to open" do
      set_policy([])
      assert Registration.mode() == :open
      assert Registration.enabled?()
      assert Registration.check("anyone@example.com") == :ok
    end

    test "closed rejects everyone and disables the pages" do
      set_policy(mode: :closed)
      refute Registration.enabled?()
      assert Registration.check("anyone@example.com") == {:error, :closed}
    end

    test "allowlist matches exact emails and @domains case-insensitively" do
      set_policy(mode: :allowlist, allowlist: ["Ops@Example.com", "@corp.example"])
      assert Registration.enabled?()
      assert Registration.check("ops@example.com") == :ok
      assert Registration.check("OPS@EXAMPLE.COM") == :ok
      assert Registration.check("someone@corp.example") == :ok
      assert Registration.check("someone@evil.example") == {:error, :not_allowlisted}
      assert Registration.check(nil) == {:error, :not_allowlisted}
    end

    test "an unknown mode fails closed" do
      set_policy(mode: :whatever)
      assert Registration.mode() == :closed
    end

    test "parse_allowlist/1 splits, trims, drops blanks and lowercases" do
      assert Registration.parse_allowlist(" A@x.com, @Y.org ,, ") == ["a@x.com", "@y.org"]
      assert Registration.parse_allowlist(nil) == []
    end
  end

  describe "Accounts.register_user/1 enforcement (issue #13)" do
    test "closed registration returns a changeset error and inserts nothing" do
      set_policy(mode: :closed)

      assert {:error, changeset} = Accounts.register_user(%{email: "new@example.com"})
      assert "registration is closed" in errors_on(changeset).email
      refute Accounts.get_user_by_email("new@example.com")
    end

    test "allowlist admits listed addresses only" do
      set_policy(mode: :allowlist, allowlist: ["@good.example"])

      assert {:error, changeset} = Accounts.register_user(%{email: "x@bad.example"})
      assert "is not permitted to register" in errors_on(changeset).email

      assert {:ok, user} = Accounts.register_user(%{email: "x@good.example"})
      assert user.email == "x@good.example"
    end
  end
end
