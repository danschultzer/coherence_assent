defmodule TestProvider do
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
      site: "http://localhost:4000/",
      authorize_url: "/oauth/authorize",
      token_url: "/oauth/token",
      user_url: "/api/user"
    ]
    |> Keyword.merge(config)
    |> Keyword.put(:strategy, OAuth2.Strategy.AuthCode)
  end

  defp normalize({:ok, %{conn: conn, client: client, user: user}}) do
    user = %{"uid"      => user["uid"],
             "name"     => user["name"],
             "email"    => user["email"]} |> Helpers.prune

    {:ok, %{conn: conn, client: client, user: user}}
  end
  defp normalize({:error, _} = response), do: response
end
