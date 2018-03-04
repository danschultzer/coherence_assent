defmodule CoherenceAssent.Strategy.Twitter do
  @moduledoc """
  Twitter OAuth 1.0 strategy.
  """

  alias CoherenceAssent.Strategy.Helpers
  alias CoherenceAssent.Strategies.OAuth, as: OAuthHelper

  @doc false
  @spec authorize_url(Conn.t, Keyword.t) :: {:ok, %{conn: Conn.t, url: String.t}}
  def authorize_url(conn, config) do
    OAuthHelper.authorize_url(conn, set_config(config))
  end

  @doc false
  @spec callback(Conn.t, Keyword.t, map) :: {:ok, %{conn: Conn.t, client: OAuth2.Client.t, user: map}} | {:error, term}
  def callback(conn, config, params) do
    config = config |> set_config

    conn
    |> OAuthHelper.callback(config, params)
    |> normalize()
  end

  defp set_config(config) do
    [
      site: "https://api.twitter.com",
      user_url: "/1.1/account/verify_credentials.json?include_entities=false&skip_status=true&include_email=true",
    ]
    |> Keyword.merge(config)
  end

  defp normalize({:ok, %{conn: conn, user: user}}) do
    user = %{"uid"         => Integer.to_string(user["id"]),
             "nickname"    => user["screen_name"],
             "email"       => user["email"],
             "location"    => user["location"],
             "name"        => user["name"],
             "image"       => user["profile_image_url_https"],
             "description" => user["description"],
             "urls"        => %{"Website" => user["url"],
                                "Twitter" => "https://twitter.com/#{user["screen_name"]}"}}
           |> Helpers.prune

    {:ok, %{conn: conn, user: user}}
  end
  defp normalize({:error, error}), do: {:error, error}
end
