defmodule CoherenceAssent.SchemaTest do
  use CoherenceAssent.TestCase

  import CoherenceAssent.Test.Fixture

  setup do
    {:ok, user: fixture(:user), params: %{name: "John Doe", password: "new_password", password_confirmation: "new_password"}}
  end

  describe "changeset/1" do
    test "doesn't have error with identity and no password", %{user: user, params: params} do
      fixture(:user_identity, user, %{provider: "test_provider", uid: "1"})

      changeset = CoherenceAssent.Test.User.changeset(user, params)
      assert changeset.valid?
    end

    test "has error with no password", %{user: user, params: params} do
      changeset = CoherenceAssent.Test.User.changeset(user, params)
      refute changeset.valid?
    end
  end

  describe "Repo.delete/1" do
    test "removes all identities", %{user: user} do
      fixture(:user_identity, user, %{provider: "test_provider", uid: "1"})
      fixture(:user_identity, user, %{provider: "test_provider", uid: "2"})

      assert length(CoherenceAssent.repo.all(CoherenceAssent.UserIdentities.UserIdentity)) == 2

      CoherenceAssent.repo.delete(user)

      assert length(CoherenceAssent.repo.all(CoherenceAssent.UserIdentities.UserIdentity)) == 0
    end
  end
end
