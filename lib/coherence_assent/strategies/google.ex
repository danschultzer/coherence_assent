defmodule CoherenceAssent.Strategy.Google do
  @moduledoc """
  Google OAuth 2.0 strategy.
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
      site: "https://www.googleapis.com/plus/v1",
      authorize_url: "https://accounts.google.com/o/oauth2/auth",
      token_url: "https://accounts.google.com/o/oauth2/token",
      user_url: "/people/me/openIdConnect",
      authorization_params: [scope: "email profile"]
    ]
    |> Keyword.merge(config)
    |> Keyword.put(:strategy, OAuth2.Strategy.AuthCode)
  end

  defp normalize({:ok, %{conn: conn, client: client, user: user}}) do
    user = %{"uid"        => user["sub"],
             "name"       => user["name"],
             "email"      => verified_email(user),
             "first_name" => user["given_name"],
             "last_name"  => user["family_name"],
             "image"      => user["picture"],
             "domain"     => user["hd"],
             "urls"       => %{"Google" => user["profile"]}}
           |> Helpers.prune

    {:ok, %{conn: conn, client: client, user: user}}
  end
  defp normalize({:error, _} = error), do: error

  defp verified_email(%{"email_verified" => "true"} = user), do: user["email"]
  defp verified_email(_), do: nil
end
