defmodule CoherenceAssent.Strategy.Basecamp do
  @moduledoc """
  Basecamp OAuth 2.0 strategy.
  """

  alias CoherenceAssent.Strategy.Helpers
  alias CoherenceAssent.Strategies.OAuth2, as: OAuth2Helper

  def authorize_url(conn, config) do
    OAuth2Helper.authorize_url(conn, set_config(config))
  end

  def callback(conn, config, params) do
    config = set_config(config)

    conn
    |> OAuth2Helper.callback(config, params)
    |> normalize
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
        |> Helpers.prune
    {:ok, %{conn: conn, client: client, user: user}}
  end
  defp normalize({:error, _} = error), do: error
end
