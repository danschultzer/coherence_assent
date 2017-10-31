defmodule CoherenceAssent.Strategy.Basecamp do
  @moduledoc """
  Basecamp OAuth 2.0 strategy.
  """

  alias CoherenceAssent.Strategy.Helpers
  alias CoherenceAssent.Strategies.OAuth2, as: OAuth2Helper

  def authorize_url(conn: conn, config: config) do
    config = config |> set_config
    OAuth2Helper.authorize_url(conn: conn, config: config)
  end

  def callback(conn: conn, config: config, params: params) do
    config = config |> set_config
    client = config |> OAuth2.Client.new()

    {:ok, %{conn: conn, client: client}}
    |> OAuth2Helper.check_conn(params)
    {:ok, client} = client
                    |> OAuth2.Client.get_token(
                      code: params["code"],
                      client_secret: config[:client_secret],
                      redirect_uri: params["redirect_uri"],
                      type: config[:authorization_params][:type]
                    )
    client
    |> OAuth2.Client.get(config[:user_url] || raise "No user URL set")
    |> process_user_response(conn, client)
    |> normalize()

  end

  defp set_config(config) do
    [
      site: "https://launchpad.37signals.com",
      authorize_url: "/authorization/new",
      token_url: "/authorization/token",
      user_url: "/authorization.json",
      authorization_params: [type: "web_server"],
    ]
    |> Keyword.merge(config)
    |> Keyword.put(:strategy, OAuth2.Strategy.AuthCode)
  end

  defp process_user_response({:ok, %OAuth2.Response{body: user}}, conn, client),
    do: {:ok, %{conn: conn, client: client, user: user}}
  defp process_user_response({:error, %OAuth2.Response{status_code: 401, body: _body}}, _conn, _client) do
    raise "Unauthorized token"
  end
  defp process_user_response({:error, %OAuth2.Error{reason: reason}}, _conn, _client) do
    raise "Error: #{inspect reason}"
  end

  defp normalize({:ok, %{conn: conn, client: client, user: user}}) do
    user =
      %{"uid"         => Integer.to_string(user["identity"]["id"]),
        "name"        => "#{user["identity"]["first_name"]} #{user["identity"]["last_name"]}",
        "first_name"  => user["identity"]["first_name"],
        "last_name"   => user["identity"]["last_name"],
        "email"       => user["identity"]["email_address"],
        "accounts"    => user["accounts"],
        "token"       => Map.from_struct(client.token) |> Map.take([:access_token, :expires_at, :refresh_token])}
        |> Helpers.prune
    {:ok, %{conn: conn, client: client, user: user}}
  end
  defp normalize({:error, _} = error), do: error
end
