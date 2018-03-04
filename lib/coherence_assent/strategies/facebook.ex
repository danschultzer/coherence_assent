defmodule CoherenceAssent.Strategy.Facebook do
  @moduledoc """
  Facebook OAuth 2.0 strategy.
  """

  alias CoherenceAssent.Strategy.Helpers
  alias CoherenceAssent.Strategies.OAuth2, as: OAuth2Helper

  @spec authorize_url(Conn.t, Keyword.t) :: {:ok, %{conn: Conn.t, url: String.t}}
  def authorize_url(conn, config) do
    OAuth2Helper.authorize_url(conn, set_config(config))
  end

  @spec callback(Conn.t, Keyword.t, map) :: {:ok, %{conn: Conn.t, client: OAuth2.Client.t, user: map}} | {:error, term}
  def callback(conn, config, params) do
    config = set_config(config)
    client = OAuth2.Client.new(config)
    {conn, state} = OAuth2Helper.retrieve_and_clear_state(conn)

    state
    |> OAuth2Helper.check_state(client, params)
    |> OAuth2Helper.get_access_token(config, params)
    |> add_client_params(config)
    |> OAuth2Helper.get_user(config[:user_url])
    |> normalize(client)
    |> case do
      {:ok, user} -> {:ok, %{conn: conn, client: client, user: user}}
      {:error, error} -> {:error, %{conn: conn, error: error}}
    end
  end

  defp set_config(config) do
    [
      site: "https://graph.facebook.com/v2.6",
      authorize_url: "https://www.facebook.com/v2.6/dialog/oauth",
      token_url: "/oauth/access_token",
      user_url: "/me",
      authorization_params: [scope: "email"],
      user_url_request_fields: "name,email"
    ]
    |> Keyword.merge(config)
    |> Keyword.put(:strategy, OAuth2.Strategy.AuthCode)
  end

  defp add_client_params({:ok, client}, config) do
    client = client
    |> OAuth2.Client.put_param(:appsecret_proof, appsecret_proof(client))
    |> OAuth2.Client.put_param(:fields, config[:user_url_request_fields])

    {:ok, client}
  end
  defp add_client_params({:error, error}, _config), do: {:error, error}

  defp normalize({:ok, user}, client) do
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

    {:ok, user}
  end
  defp normalize({:error, error}, _client), do: {:error, error}

  defp image_url(client, user) do
    "#{client.site}/#{user["id"]}/picture"
  end

  defp appsecret_proof(client) do
    :sha256
    |> :crypto.hmac(client.client_secret, client.token.access_token)
    |> Base.encode16()
  end
end
