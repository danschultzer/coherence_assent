defmodule CoherenceAssent.Strategy.Basecamp do
  @moduledoc """
  Basecamp OAuth 2.0 strategy.
  """

  alias CoherenceAssent.Strategy.Helpers
  alias CoherenceAssent.Strategy.OAuth2, as: OAuth2Helper

  @spec authorize_url(Conn.t, Keyword.t) :: {:ok, %{conn: Conn.t, url: String.t}}
  def authorize_url(conn, config) do
    OAuth2Helper.authorize_url(conn, set_config(config))
  end

  @spec callback(Conn.t, Keyword.t, map) :: {:ok, %{conn: Conn.t, client: OAuth2.Client.t, user: map}} | {:error, term}
  def callback(conn, config, params) do
    config = set_config(config)

    conn
    |> OAuth2Helper.callback(config, params)
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

  defp normalize({:ok, %{conn: conn, client: client, user: user}}) do
    user =
      %{"uid"         => Integer.to_string(user["identity"]["id"]),
        "name"        => "#{user["identity"]["first_name"]} #{user["identity"]["last_name"]}",
        "first_name"  => user["identity"]["first_name"],
        "last_name"   => user["identity"]["last_name"],
        "email"       => user["identity"]["email_address"],
        "accounts"    => user["accounts"]}
      |> Helpers.prune()

    {:ok, %{conn: conn, client: client, user: user}}
  end
  defp normalize({:error, error}), do: {:error, error}
end
