defmodule CoherenceAssent.AuthControllerTest do
  use CoherenceAssent.Test.ConnCase

  import CoherenceAssent.Test.Fixture
  import OAuth2.TestHelpers

  @provider "test_provider"
  @callback_params %{code: "test", redirect_uri: ""}

  setup %{conn: conn} do
    server = Bypass.open

    Application.put_env(:coherence_assent, :providers, [
                          test_provider: [
                            client_id: "client_id",
                            client_secret: "abc123",
                            site: bypass_server(server),
                            strategy: TestProvider
                          ]
                        ])

    user = fixture(:user)
    {:ok, conn: conn, user: user, server: server}
  end

  test "index/2 redirects to authorization url", %{conn: conn, server: server} do
    conn = get conn, coherence_assent_auth_path(conn, :index, @provider)

    assert redirected_to(conn) =~ "http://localhost:#{server.port}/oauth/authorize?client_id=client_id&redirect_uri=http%3A%2F%2Flocalhost%2Fauth%2Ftest_provider%2Fcallback&response_type=code&state="
  end

  describe "callback/2" do
    test "with current_user session", %{conn: conn, server: server, user: user} do
      bypass_oauth(server)

      conn = conn
      |> put_coherence_session(user)
      |> get(coherence_assent_auth_path(conn, :callback, @provider, @callback_params))

      assert redirected_to(conn) == "/session_created"
      assert length(get_user_identities()) == 1
    end

    test "with current_user session and identity bound to another user", %{conn: conn, server: server, user: user} do
      bypass_oauth(server)
      fixture(:user_identity, user, %{provider: @provider, uid: "1"})

      conn = conn
      |> put_coherence_session(user)
      |> get(coherence_assent_auth_path(conn, :callback, @provider, @callback_params))

      assert redirected_to(conn) == Coherence.ControllerHelpers.router_helpers().registration_path(conn, :new)
      assert get_flash(conn, :error) == "The %{provider} account is already bound to another user."
    end

    test "with valid params", %{conn: conn, server: server, user: user} do
      bypass_oauth(server, %{}, %{email: "newuser@example.com"})

      conn = get conn, coherence_assent_auth_path(conn, :callback, @provider, @callback_params)

      assert redirected_to(conn) == "/registration_created"
      assert [user_identity] = get_user_identities()

      new_user = CoherenceAssent.repo.preload(user_identity, :user).user
      refute new_user.id == user.id
      assert CoherenceAssent.Test.User.confirmed?(new_user)
    end

    test "with missing params", %{conn: conn, server: server} do
      bypass_oauth(server, %{}, %{email: "newuser@example.com", name: ""})

      conn = get conn, coherence_assent_auth_path(conn, :callback, @provider, @callback_params)

      assert redirected_to(conn) == Coherence.Config.logged_out_url(conn)
      assert get_flash(conn, :error) == "Could not sign in. Please try again."
    end

    test "with missing oauth email", %{conn: conn, server: server} do
      bypass_oauth(server)

      conn = get conn, coherence_assent_auth_path(conn, :callback, @provider, @callback_params)

      assert redirected_to(conn) == "/auth/test_provider/new"
      assert length(get_user_identities()) == 0
      assert Plug.Conn.get_session(conn, "coherence_assent_params") == %{"name" => "Dan Schultzer", "uid" => "1"}
    end

    test "with an existing different registered user email", %{conn: conn, server: server, user: user} do
      bypass_oauth(server, %{}, %{email: user.email})

      conn = get conn, coherence_assent_auth_path(conn, :callback, @provider, @callback_params)

      assert html_response(conn, 200) =~ "has already been taken"
      assert length(get_user_identities()) == 0
      assert Plug.Conn.get_session(conn, "coherence_assent_params") == %{"email" => "user@example.com", "name" => "Dan Schultzer", "uid" => "1"}
    end

    test "with valid params and existing user identity", %{conn: conn, server: server, user: user} do
      bypass_oauth(server, %{}, %{email: user.email})

      fixture(:user_identity, user, %{provider: @provider, uid: "1"})

      conn = get conn, coherence_assent_auth_path(conn, :callback, @provider, @callback_params)

      assert redirected_to(conn) == "/session_created"
    end

    test "with failed token generation", %{conn: conn, server: server} do
      Bypass.expect_once server, "POST",  "/oauth/token", fn conn ->
        send_resp(conn, 401, Poison.encode!(%{error: "invalid_client"}))
      end

      assert_raise CoherenceAssent.RequestError, "invalid_client", fn ->
        get conn, coherence_assent_auth_path(conn, :callback, @provider, @callback_params)
      end
    end

    test "with differing state", %{conn: conn} do
      assert_raise CoherenceAssent.CallbackCSRFError, fn ->
        conn
        |> session_conn()
        |> Plug.Conn.put_session("coherence_assent.state", "1")
        |> get(coherence_assent_auth_path(conn, :callback, @provider, Map.merge(@callback_params, %{"state" => "2"})))
      end
    end

    test "with same state", %{conn: conn, server: server} do
      bypass_oauth(server)

      conn = conn
      |> session_conn()
      |> Plug.Conn.put_session("coherence_assent.state", "1")
      |> get(coherence_assent_auth_path(conn, :callback, @provider, Map.merge(@callback_params, %{"state" => "1"})))

      assert redirected_to(conn) == "/auth/test_provider/new"
    end

    test "with timeout", %{conn: conn, server: server} do
      Bypass.down(server)

      assert_raise OAuth2.Error, "Connection refused", fn ->
        get conn, coherence_assent_auth_path(conn, :callback, @provider, @callback_params)
      end
    end

    defp bypass_oauth(server, token_params \\ %{}, user_params \\ %{}) do
      Bypass.expect_once server, "POST", "/oauth/token", fn conn ->
        send_resp(conn, 200, Poison.encode!(Map.merge(%{access_token: "access_token"}, token_params)))
      end

      Bypass.expect_once server, "GET", "/api/user", fn conn ->
        send_resp(conn, 200, Poison.encode!(Map.merge(%{uid: "1", name: "Dan Schultzer"}, user_params)))
      end
    end

    defp get_user_identities do
      CoherenceAssent.UserIdentities.UserIdentity
      |> CoherenceAssent.repo.all
    end
  end

  describe "delete/2" do
    setup :put_coherence_session

    test "with no user password", %{conn: conn, user: user} do
      fixture(:user_identity, user, %{provider: @provider, uid: "1"})

      conn = delete(conn, coherence_assent_auth_path(conn, :delete, @provider))

      assert redirected_to(conn) == Coherence.ControllerHelpers.router_helpers().registration_path(conn, :edit)
      assert length(get_user_identities()) == 1
      assert get_flash(conn, :error) == "Authentication cannot be removed until you've entered a password for your account."
    end

    test "with two identities", %{conn: conn, user: user} do
      fixture(:user_identity, user, %{provider: @provider, uid: "1"})
      fixture(:user_identity, user, %{provider: "another_provider", uid: "2"})

      conn = delete(conn, coherence_assent_auth_path(conn, :delete, @provider))

      assert redirected_to(conn) == Coherence.ControllerHelpers.router_helpers().registration_path(conn, :edit)
      assert length(get_user_identities()) == 1
    end

    test "with user password", %{conn: conn, user: user} do
      user = user
             |> CoherenceAssent.Test.User.changeset(%{password: "test", password_confirmation: "test"}, :password)
             |> CoherenceAssent.repo.update!
      fixture(:user_identity, user, %{provider: @provider, uid: "1"})

      conn = delete(conn, coherence_assent_auth_path(conn, :delete, @provider))

      assert redirected_to(conn) == Coherence.ControllerHelpers.router_helpers().registration_path(conn, :edit)
      assert length(get_user_identities()) == 0
    end

    test "with current_user session without provider", %{conn: conn} do
      conn = delete(conn, coherence_assent_auth_path(conn, :delete, @provider))

      assert redirected_to(conn) == Coherence.ControllerHelpers.router_helpers().registration_path(conn, :edit)
    end
  end

  defp put_coherence_session(conn, user) do
    id = UUID.uuid1
    Coherence.CredentialStore.Session.put_credentials({id, user, :id})

    conn
    |> session_conn()
    |> Plug.Conn.put_session("session_auth", id)
  end
  defp put_coherence_session(%{conn: conn, user: user}) do
    {:ok, conn: put_coherence_session(conn, user), user: user}
  end
end
