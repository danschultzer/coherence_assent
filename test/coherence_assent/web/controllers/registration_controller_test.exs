defmodule CoherenceAssent.RegistrationControllerTest do
  use CoherenceAssent.Test.ConnCase

  import CoherenceAssent.Test.Fixture
  import Swoosh.TestAssertions

  @provider "test_provider"

  setup %{conn: conn} do
    conn = conn
    |> session_conn()
    |> Plug.Conn.put_session(:coherence_assent_params, %{"uid" => "1", "name" => "John Doe"})

    {:ok, conn: conn}
  end

  test "add_login_field/2 shows", %{conn: conn} do
    conn = get conn, coherence_assent_registration_path(conn, :add_login_field, @provider)
    assert html_response(conn, 200)
  end

  test "add_login_field/2 with missing session", %{conn: conn} do
    conn = conn
    |> Plug.Conn.delete_session(:coherence_assent_params)
    |> get(coherence_assent_registration_path(conn, :add_login_field, @provider))

    assert redirected_to(conn) == Coherence.Config.logged_out_url()
    assert get_flash(conn, :error) == "Invalid Request."
  end

  test "create/2 with missing session", %{conn: conn} do
    conn = conn
    |> Plug.Conn.delete_session(:coherence_assent_params)
    |> post(coherence_assent_registration_path(conn, :create, @provider), %{registration: %{email: "foo@example.com"}})

    assert redirected_to(conn) == Coherence.Config.logged_out_url()
    assert get_flash(conn, :error) == "Invalid Request."
  end

  test "create/2 with valid", %{conn: conn} do
    conn = post conn, coherence_assent_registration_path(conn, :create, @provider), %{registration: %{email: "foo@example.com"}}

    assert redirected_to(conn) == "/registration_created"
    assert [new_user] = CoherenceAssent.repo.all(CoherenceAssent.Test.User)
    assert new_user.email == "foo@example.com"
    assert get_flash(conn, :info) == "Confirmation email sent."
    refute CoherenceAssent.Test.User.confirmed?(new_user)
    assert_email_sent CoherenceAssent.Coherence.UserEmail.confirmation(nil, nil)
  end

  describe "when resource owner not confirmable" do
    setup %{conn: conn} do
      prev_opts = Application.get_env(:coherence, :opts)
      on_exit fn ->
        Application.put_env(:coherence, :opts, prev_opts)
      end
      Application.put_env(:coherence, :opts, [:authenticatable, :recoverable, :lockable, :trackable, :unlockable_with_token, :registerable])

      {:ok, conn: conn}
    end

    test "create/2 with valid when not confirmable", %{conn: conn} do
      conn = post conn, coherence_assent_registration_path(conn, :create, @provider), %{registration: %{email: "foo@example.com"}}

      assert is_nil(get_flash(conn, :notice))
      assert_no_email_sent()
    end
  end

  test "create/2 with taken login_field", %{conn: conn} do
    fixture(:user, %{email: "foo@example.com"})

    conn = post conn, coherence_assent_registration_path(conn, :create, @provider), %{registration: %{email: "foo@example.com"}}

    assert html_response(conn, 200) =~ "has already been taken"
  end

  test "create/2 with invalid login_field", %{conn: conn} do
    conn = post conn, coherence_assent_registration_path(conn, :create, @provider), %{registration: %{email: "foo"}}

    assert html_response(conn, 200) =~ "has invalid format"
  end
end
