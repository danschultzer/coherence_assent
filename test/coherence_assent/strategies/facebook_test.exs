defmodule CoherenceAssent.Strategy.FacebookTest do
  use CoherenceAssent.Test.ConnCase

  import OAuth2.TestHelpers
  alias CoherenceAssent.Strategy.Facebook

  setup %{conn: conn} do
    conn = session_conn(conn)

    bypass = Bypass.open
    config = [site: bypass_server(bypass)]
    params = %{"code" => "test", "redirect_uri" => "test"}

    {:ok, conn: conn, config: config, params: params, bypass: bypass}
  end

  test "authorize_url/2", %{conn: conn, config: config} do
    assert {:ok, %{conn: _conn, url: url}} = Facebook.authorize_url(conn, config)
    assert url =~ "https://www.facebook.com/v2.6/dialog/oauth?client_id="
  end

  describe "callback/2" do
    test "normalizes data", %{conn: conn, config: config, params: params, bypass: bypass} do
      Bypass.expect_once bypass, "POST", "/oauth/access_token", fn conn ->
        send_resp(conn, 200, Poison.encode!(%{access_token: "access_token"}))
      end

      Bypass.expect_once bypass, "GET", "/me", fn conn ->
        user = %{name: "Dan Schultzer",
                 email: "foo@example.com",
                 id: "1"}
        Plug.Conn.resp(conn, 200, Poison.encode!(user))
      end

      expected = %{"email" => "foo@example.com",
                   "image" => "http://localhost:#{bypass.port}/1/picture",
                   "name" => "Dan Schultzer",
                   "uid" => "1",
                   "urls" => %{}}

     {:ok, %{user: user}} = Facebook.callback(conn, config, params)
      assert expected == user
    end
  end
end
