defmodule CoherenceAssent.Strategy.OAuth2Test do
  use CoherenceAssent.Test.ConnCase

  import OAuth2.TestHelpers
  alias CoherenceAssent.Strategy.OAuth2, as: OAuth2Strategy

  setup %{conn: conn} do
    conn = session_conn(conn)

    bypass = Bypass.open()
    config = [site: bypass_server(bypass), user_url: "/api/user"]

    {:ok, conn: conn, config: config, bypass: bypass}
  end

  test "authorize_url/2", %{conn: conn, config: config} do
    assert {:ok, %{conn: conn, url: url}} = OAuth2Strategy.authorize_url(conn, config)

    state = Plug.Conn.get_session(conn, "coherence_assent.state")

    assert url == "#{config[:site]}/oauth/authorize?client_id=&redirect_uri=&response_type=code&state=#{state}"
  end

  describe "callback/2" do
    setup %{conn: conn, config: config, bypass: bypass} do
      conn = Plug.Conn.put_session(conn, "coherence_assent.state", "test")
      params = %{"code" => "test", "redirect_uri" => "test", "state" => "test"}

      {:ok, conn: conn, config: config, params: params, bypass: bypass}
    end

    test "normalizes data", %{conn: conn, config: config, params: params, bypass: bypass} do
      Bypass.expect_once bypass, "POST", "/oauth/token", fn conn ->
        send_resp(conn, 200, Poison.encode!(%{access_token: "access_token"}))
      end

      Bypass.expect_once bypass, "GET", "/api/user", fn conn ->
        user = %{name: "Dan Schultzer", email: "foo@example.com", uid: "1"}
        Plug.Conn.resp(conn, 200, Poison.encode!(user))
      end

      assert {:ok, %{conn: conn, user: user}} = OAuth2Strategy.callback(conn, config, params)
      assert user == %{"email" => "foo@example.com", "name" => "Dan Schultzer", "uid" => "1"}
      assert is_nil(Plug.Conn.get_session(conn, "coherence_assent.state"))
    end

    test "access token error with 200 response", %{conn: conn, config: config, params: params, bypass: bypass} do
      Bypass.expect_once bypass, "POST", "/oauth/token", fn conn ->
        send_resp(conn, 200, Poison.encode!(%{"error" => "error", "error_description" => "Error description"}))
      end

      expected = %CoherenceAssent.RequestError{error: "error", message: "Error description"}

      assert {:error, %{conn: conn, error: error}} = OAuth2Strategy.callback(conn, config, params)
      assert error == expected
      assert is_nil(Plug.Conn.get_session(conn, "coherence_assent.state"))
    end

    test "access token error with no 2XX response", %{conn: conn, config: config, params: params, bypass: bypass} do
      Bypass.expect_once bypass, "POST", "/oauth/token", fn conn ->
        send_resp(conn, 500, Poison.encode!(%{error: "Error"}))
      end

      expected = %CoherenceAssent.RequestError{error: nil, message: "Error"}

      assert {:error, %{conn: %Plug.Conn{}, error: error}} = OAuth2Strategy.callback(conn, config, params)
      assert error == expected
    end

    test "configuration error", %{conn: conn, config: config, params: params, bypass: bypass} do
      config = Keyword.put(config, :user_url, nil)

      Bypass.expect_once bypass, "POST", "/oauth/token", fn conn ->
        send_resp(conn, 200, Poison.encode!(%{access_token: "access_token"}))
      end

      expected = %CoherenceAssent.ConfigurationError{message: "No user URL set"}

      assert {:error, %{conn: %Plug.Conn{}, error: error}} = OAuth2Strategy.callback(conn, config, params)
      assert error == expected
    end

    test "user url connection error", %{conn: conn, config: config, params: params, bypass: bypass} do
      config = Keyword.put(config, :user_url, "http://localhost:8888/api/user")

      Bypass.expect_once bypass, "POST", "/oauth/token", fn conn ->
        send_resp(conn, 200, Poison.encode!(%{access_token: "access_token"}))
      end

      expected = %OAuth2.Error{reason: :econnrefused}

      assert {:error, %{conn: %Plug.Conn{}, error: error}} = OAuth2Strategy.callback(conn, config, params)
      assert error == expected
    end

    test "user url unauthorized access token", %{conn: conn, config: config, params: params, bypass: bypass} do
      Bypass.expect_once bypass, "POST", "/oauth/token", fn conn ->
        send_resp(conn, 200, Poison.encode!(%{access_token: "access_token"}))
      end

      Bypass.expect_once bypass, "GET", "/api/user", fn conn ->
        Plug.Conn.resp(conn, 401, Poison.encode!(%{"error" => "Unauthorized"}))
      end

      expected = %CoherenceAssent.RequestError{message: "Unauthorized token"}

      assert {:error, %{conn: %Plug.Conn{}, error: error}} = OAuth2Strategy.callback(conn, config, params)
      assert error == expected
    end
  end
end
