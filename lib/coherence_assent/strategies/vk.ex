defmodule CoherenceAssent.Strategy.VK do
  @moduledoc """
  VK.com OAuth 2.0 strategy.
  """

  alias CoherenceAssent.Strategy.Helpers
  alias CoherenceAssent.Strategies.OAuth2, as: OAuth2Helper

  def authorize_url(conn, config) do
    OAuth2Helper.authorize_url(conn, set_config(config))
  end

  def callback(conn, config, params) do
    config = set_config(config)
    client = OAuth2.Client.new(config)

    conn
    |> OAuth2Helper.check_conn(client, params)
    |> OAuth2Helper.get_access_token(config, params)
    |> get_user(config)
    |> get_response()
    |> normalize()
  end

  defp set_config(config) do
    profile_fields = ["uid", "first_name", "last_name",
                      "photo_200", "screen_name", "verified"]

    user_url_params = %{
      "fields" => Enum.join(profile_fields, ","),
      "v" => "5.69",
      "https" => "1"
    } |> Map.merge(config[:user_url_params] || %{})

    [
      site: "https://api.vk.com",
      authorize_url: "https://oauth.vk.com/authorize",
      token_url: "https://oauth.vk.com/access_token",
      user_url: "/method/users.get",
      authorization_params: [scope: "email"],
      user_url_params: user_url_params
    ]
    |> Keyword.merge(config)
    |> Keyword.put(:strategy, OAuth2.Strategy.AuthCode)
  end

  defp get_user({:ok, %{conn: conn, client: client}}, config) do
    user_url_params = config[:user_url_params] |> Map.put("access_token", client.token.access_token)
    user_url = config[:user_url] <> "?" <> URI.encode_query(user_url_params)

    OAuth2Helper.get_user({:ok, %{conn: conn, client: client}}, user_url)
  end
  defp get_user({:error, _} = error, _config), do: error

  defp get_response({:ok, %{client: client, user: %{"response" => [user]}} = resp}) do
    email = Map.get(client.token.other_params, "email")
    user = Map.put_new(user, "email", email)

    {:ok, Map.put(resp, :user, user)}
  end
  defp get_response({:ok, resp}), do: {:error, %{error: "Retrieved invalid response: #{inspect resp.user}"}}
  defp get_response(resp), do: resp

  defp normalize({:ok, %{conn: conn, client: client, user: user}}) do
    user = %{"uid"         => user["id"] |> to_string,
             "nickname"    => user["screen_name"],
             "first_name"  => user["first_name"],
             "last_name"   => user["last_name"],
             "name"        => [user["first_name"], user["last_name"]] |> Enum.join(" "),
             "email"       => user["email"],
             "image"       => user["photo_200"],
             "verified"    => user["verified"] > 0}
           |> Helpers.prune

    {:ok, %{conn: conn, client: client, user: user}}
  end
  defp normalize({:error, _} = error), do: error
end