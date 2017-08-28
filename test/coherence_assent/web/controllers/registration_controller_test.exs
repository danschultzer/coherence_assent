defmodule CoherenceAssent.RegistrationControllerTest do
  use CoherenceAssent.Test.ConnCase

  import CoherenceAssent.Test.Fixture

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
    refute CoherenceAssent.Test.User.confirmed?(new_user)
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
