defmodule CoherenceAssent.Strategy.Facebook do
  @moduledoc """
  Facebook OAuth 2.0 strategy.
  """

  alias CoherenceAssent.Strategy.Helpers
  alias CoherenceAssent.Strategies.OAuth2, as: OAuth2Helper

  def authorize_url(conn, config) do
    OAuth2Helper.authorize_url(conn, set_config(config))
  end

  def callback(conn, config, params) do
    config = config |> set_config
    client = config |> OAuth2.Client.new()

    conn
    |> OAuth2Helper.check_conn(client, params)
    |> OAuth2Helper.get_access_token(config, params)
    |> get_user(config)
    |> normalize()
  end

  defp set_config(config) do
    [
      site: "https://graph.facebook.com/v2.6",
      authorize_url: "https://www.facebook.com/v2.6/dialog/oauth",
      token_url: "/oauth/access_token",
      user_url: "/me",
      authorization_params: [{"scope", "email"}],
      user_url_request_fields: "name,email"
    ]
    |> Keyword.merge(config)
    |> Keyword.put(:strategy, OAuth2.Strategy.AuthCode)
  end

  defp get_user({:ok, %{conn: conn, client: client}}, config) do
    client = client
    |> OAuth2.Client.put_param(:appsecret_proof, appsecret_proof(client))
    |> OAuth2.Client.put_param(:fields, config[:user_url_request_fields])

    OAuth2Helper.get_user({:ok, %{conn: conn, client: client}}, config[:user_url])
  end
  defp get_user({:error, _} = error, _config), do: error

  defp normalize({:ok, %{conn: conn, client: client, user: user}}) do
    user = %{"uid"         => user["id"],
             "nickname"    => user["username"],
             "email"       => user["email"],
             "name"        => user["name"],
             "first_name"  => user["first_name"],
             "last_name"   => user["last_name"],
             "location"    => (user["location"] || %{})["name"],
             "image"       => image_url(client, user),
             "description" => user["bio"],
             "urls"        => %{"Facebook" => user["link"],
                                "Website"  => user["website"]},
             "verified"    => user["verified"]}
           |> Helpers.prune

    {:ok, %{conn: conn, client: client, user: user}}
  end
  defp normalize({:error, _} = error), do: error

  defp image_url(client, user) do
    "#{client.site}/#{user["id"]}/picture"
  end

  defp appsecret_proof(client) do
    :sha256
    |> :crypto.hmac(client.client_secret, client.token.access_token)
    |> Base.encode16
  end
end
