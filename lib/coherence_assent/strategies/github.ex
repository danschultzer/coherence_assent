defmodule CoherenceAssent.Strategy.Github do
  @moduledoc """
  Github OAuth 2.0 strategy.
  """

  alias CoherenceAssent.Strategy.Helpers
  alias CoherenceAssent.Strategies.OAuth2, as: OAuth2Helper

  def authorize_url(conn: conn, config: config) do
    config = config |> set_config
    OAuth2Helper.authorize_url(conn: conn, config: config)
  end

  def callback(conn: conn, config: config, params: params) do
    config = config |> set_config

    [conn: conn, config: config, params: params]
    |> OAuth2Helper.callback()
    |> get_email
    |> normalize
  end

  defp set_config(config) do
    [
      site: "https://api.github.com",
      authorize_url: "https://github.com/login/oauth/authorize",
      token_url: "https://github.com/login/oauth/access_token",
      user_url: "/user",
      authorization_params: [scope: "user,user:email"]
    ]
    |> Keyword.merge(config)
    |> Keyword.put(:strategy, OAuth2.Strategy.AuthCode)
  end

  defp get_email({:ok, %{conn: conn, client: client, user: user}}) do
    case OAuth2.Client.get(client, "/user/emails") do
      {:ok, %OAuth2.Response{body: emails}} ->
        user = Map.put(user, "email", get_primary_email(emails))
        {:ok, %{conn: conn, client: client, user: user}}

      {:error, error} ->
        {:error, %{conn: conn, error: error}}
    end
  end
  defp get_email(response), do: response

  defp get_primary_email(emails) do
    emails
    |> Enum.find(%{}, fn(element) -> element["primary"] && element["verified"] end)
    |> Map.fetch("email")
    |> case do
      {:ok, email} -> email
      :error       -> nil
    end
  end

  defp normalize({:ok, %{conn: conn, client: client, user: user}}) do
    user = %{"uid"      => Integer.to_string(user["id"]),
             "nickname" => user["login"],
             "email"    => user["email"],
             "name"     => user["name"],
             "image"    => user["avatar_url"],
             "urls"     => %{"GitHub" => user["html_url"],
                             "Blog"   => user["blog"]}}
           |> Helpers.prune

    {:ok, %{conn: conn, client: client, user: user}}
  end
  defp normalize({:error, _} = error), do: error
end
