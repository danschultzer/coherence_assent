defmodule CoherenceAssent.VKTest do
  use CoherenceAssent.Test.ConnCase

  import OAuth2.TestHelpers
  alias CoherenceAssent.Strategy.VK

  setup %{conn: conn} do
    conn = session_conn(conn)

    bypass = Bypass.open
    config = [site: bypass_server(bypass),
              authorize_url: "/authorize",
              token_url: "/access_token"]
    params = %{"code" => "test", "redirect_uri" => "test"}

    {:ok, conn: conn, config: config, params: params, bypass: bypass}
  end

  test "authorize_url/2", %{conn: conn, config: config} do
    assert {:ok, %{conn: _conn, url: url}} = VK.authorize_url(conn, config)
    assert url =~ "/authorize"
  end

  describe "callback/2" do
    test "normalizes data", %{conn: conn, config: config, params: params, bypass: bypass} do
      Bypass.expect_once bypass, "POST", "/access_token", fn conn ->
        send_resp(conn, 200, Poison.encode!(%{"access_token" => "access_token", "email" => "lindsay.stirling@example.com"}))
      end

      Bypass.expect_once bypass, "GET", "/method/users.get", fn conn ->
        query = Plug.Conn.fetch_query_params(conn)

        assert query.params["fields"] == "uid,first_name,last_name,photo_200,screen_name,verified"
        assert query.params["v"] == "5.69"
        assert query.params["access_token"] == "access_token"

        users = [%{"id" => 210700286,
                   "first_name" => "Lindsay",
                   "last_name" => "Stirling",
                   "screen_name" => "lindseystirling",
                   "photo_200" => "https://pp.userapi.com/c840637/v840637830/2d20e/wMuAZn-RFak.jpg",
                   "verified" => 1}]

        Plug.Conn.resp(conn, 200, Poison.encode!(%{"response" => users}))
      end

      expected = %{"email" => "lindsay.stirling@example.com",
                   "first_name" => "Lindsay",
                   "last_name" => "Stirling",
                   "name" => "Lindsay Stirling",
                   "nickname" => "lindseystirling",
                   "uid" => "210700286",
                   "image" => "https://pp.userapi.com/c840637/v840637830/2d20e/wMuAZn-RFak.jpg",
                   "verified" => true}

      {:ok, %{user: user}} = VK.callback(conn, config, params)
      assert expected == user
    end
  end
end
