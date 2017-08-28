defmodule CoherenceAssent.ViewHelpersTest do
  use CoherenceAssent.Test.ConnCase
  import CoherenceAssent.Test.Fixture
  alias CoherenceAssent.Test.Web.ViewHelpers
  import Phoenix.HTML.Link, only: [link: 2]

  setup %{conn: conn} do
    Application.put_env(:coherence_assent, :providers, [
                          test_provider: [
                            strategy: TestProvider
                          ]
                        ])
    {:ok, conn: conn}
  end

  test "oauth_links/1", %{conn: conn} do
    [safe: iodata] = ViewHelpers.oauth_links(conn)
    assert {:safe, iodata} == link("Sign in with %{provider}", to: "/auth/test_provider")

    user = fixture(:user)
    fixture(:user_identity, user, %{provider: "test_provider", uid: "1"})

    [safe: iodata] = ViewHelpers.oauth_links(conn, user)
    assert {:safe, iodata} == link("Remove %{provider} authentication", to: "/auth/test_provider", method: "delete")
  end
end
