defmodule CoherenceAssent.Strategy.Github do
  @moduledoc """
  Github OAuth 2.0 strategy.
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
    |> get_email(config)
    |> normalize
  end

  defp set_config(config) do
    [
      site: "https://api.github.com",
      authorize_url: "https://github.com/login/oauth/authorize",
      token_url: "https://github.com/login/oauth/access_token",
      user_url: "/user",
      user_emails_url: "/user/emails",
      authorization_params: [scope: "read:user,user:email"]
    ]
    |> Keyword.merge(config)
    |> Keyword.put(:strategy, OAuth2.Strategy.AuthCode)
  end

  defp get_email({:ok, %{conn: conn, client: client, user: user}}, config) do
    case OAuth2.Client.get(client, config[:user_emails_url]) do
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
