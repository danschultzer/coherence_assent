defmodule CoherenceAssent.Strategies.OAuth do
  @moduledoc """
  OAuth 1.0 strategy.
  """

  @doc false
  @spec authorize_url(Conn.t, map) :: {:ok, %{conn: Conn.t, token: String.t, url: String.t}} | {:error, term}
  def authorize_url(conn, config) do
    {:ok, %{conn: conn}}
    |> get_request_token(config, [{"oauth_callback", config[:redirect_uri]}])
    |> build_authorize_url(config)
  end

  @doc false
  @spec callback(Conn.t, map, map) :: {:ok, %{conn: Conn.t, user: map}} | {:error, term}
  def callback(conn, config, %{"oauth_token" => oauth_token, "oauth_verifier" => oauth_verifier}) do
    conn
    |> get_access_token(config, oauth_token, oauth_verifier)
    |> get_user(config)
  end

  defp get_request_token({:ok, %{conn: conn}}, config, params) do
    creds = OAuther.credentials(consumer_key: config[:consumer_key],
                                consumer_secret: config[:consumer_secret])
    request_token_url = process_url(config, config[:request_token_url] || "/oauth/request_token")

    [site: config[:site],
     url: request_token_url,
     method: "post",
     params: params,
     body: "",
     creds: creds]
    |> request
    |> process_request_token_response(conn)
  end

  defp build_authorize_url({:ok, %{conn: conn, token: token}}, config) do
    url = process_url(config, config[:authorize_url] || "/oauth/authenticate")
    url = url <> "?" <> URI.encode_query(%{oauth_token: token["oauth_token"]})

    {:ok, %{conn: conn, token: token, url: url}}
  end
  defp build_authorize_url({:error, error}, _config), do: {:error, error}

  @doc false
  @spec get_access_token(Conn.t, map, String.t, String.t) :: {:ok, %{conn: Conn.t, token: String.t}} | {:error, term}
  def get_access_token(conn, config, oauth_token, oauth_verifier) do
    creds = OAuther.credentials(consumer_key: config[:consumer_key],
                                consumer_secret: config[:consumer_secret],
                                token: oauth_token)
    access_token_url = process_url(config, config[:access_token_url] || "/oauth/access_token")

    [site: config[:site],
     url: access_token_url,
     method: "post",
     params: [{"oauth_verifier", oauth_verifier}],
     body: "",
     creds: creds]
    |> request
    |> process_request_token_response(conn)
  end

  defp request(site: site, url: url, method: method, params: params, body: body, creds: creds) do
    signed_params = OAuther.sign(method, url, params, creds)
    {header, req_params} = OAuther.header(signed_params)

    method
    |> OAuth2.Request.request(%OAuth2.Client{site: site}, url, body, [header], [form: req_params])
    |> case do
         {:ok, response} ->
           {:ok, response.body}
         {:error, error} ->
           {:error, error}
       end
  end

  defp process_request_token_response({:ok, body}, conn),
    do: {:ok, %{conn: conn, token: URI.decode_query(body)}}
  defp process_request_token_response({:error, error}, conn),
    do: {:error, %{conn: conn, error: error}}

  @doc false
  @spec get_user({:ok, map} | {:error, term}, Keyword.t) :: {:ok, map} | {:error, term}
  def get_user({:ok, %{conn: conn, token: token}}, config) do
    creds = OAuther.credentials(consumer_key: config[:consumer_key],
                                consumer_secret: config[:consumer_secret],
                                token: token["oauth_token"],
                                token_secret: token["oauth_token_secret"])

    [site: config[:site],
     url: process_url(config, config[:user_url]),
     method: "get",
     params: [],
     body: "",
     creds: creds]
    |> request
    |> process_user_response(conn)
  end
  def get_user({:error, _} = error, _config), do: error

  defp process_user_response({:ok, user}, conn),
    do: {:ok, %{conn: conn, user: user}}
  defp process_user_response({:error, error}, _conn) do
    raise "Error: #{inspect error}"
  end

  defp process_url(config, url) do
    case String.downcase(url) do
      <<"http://"::utf8, _::binary>> -> url
      <<"https://"::utf8, _::binary>> -> url
      _ -> config[:site] <> url
    end
  end
end
