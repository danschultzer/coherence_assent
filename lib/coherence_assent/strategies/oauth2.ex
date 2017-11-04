defmodule CoherenceAssent.Strategies.OAuth2 do
  @moduledoc """
  OAuth 2.0 strategy.
  """

  @doc false
  @spec authorize_url(Conn.t, Keyword.t) :: {:ok, %{conn: Conn.t, url: String.t}}
  def authorize_url(conn, config) do
    state        = gen_state()
    params       = authorization_params(config, state: state, redirect_uri: config[:redirect_uri])

    url          = config
                   |> OAuth2.Client.new()
                   |> OAuth2.Client.authorize_url!(params)
    conn         = Plug.Conn.put_session(conn, "coherence_assent.state", state)

    {:ok, %{conn: conn, url: url}}
  end

  defp authorization_params(config, params) do
    Keyword.get(config, :authorization_params, []) ++ params
  end

  @doc false
  @spec callback(Conn.t, map, map) :: {:ok, %{conn: Conn.t, client: OAuth2.Client.t, user: map}} | {:error, term}
  def callback(conn, config, params) do
    client = OAuth2.Client.new(config)

    conn
    |> check_conn(client, params)
    |> get_access_token(config, params)
    |> get_user(config[:user_url])
  end

  @doc false
  @spec check_conn(Conn.t, OAuth2.Client.t, map) :: {:ok, map} | {:error, term}
  def check_conn(conn, _client, %{"error" => _} = params) do
    conn = Plug.Conn.delete_session(conn, "coherence_assent.state")

    {:error, %{conn: conn,
               error: %CoherenceAssent.CallbackError{
                 message: params["error_description"] || params["error_reason"] || params["error"],
                 error: params["error"],
                 error_uri: params["error_uri"]}}}
  end
  def check_conn(conn, client, %{"code" => _code} = params) do
    state = Plug.Conn.get_session(conn, "coherence_assent.state")
    conn = Plug.Conn.delete_session(conn, "coherence_assent.state")

    case params["state"] do
      ^state -> {:ok, %{conn: conn, client: client}}
      _      -> {:error, %{conn: conn, error: %CoherenceAssent.CallbackCSRFError{}}}
    end
  end

  @doc false
  @spec get_access_token({:ok, map} | {:error, term}, map, map) :: {:ok, map} | {:error, term}
  def get_access_token({:ok, %{conn: conn, client: client}}, config, %{"code" => code, "redirect_uri" => redirect_uri}) do
    params = authorization_params(config,
                                  code: code,
                                  client_secret: client.client_secret,
                                  redirect_uri: redirect_uri)

    client
    |> OAuth2.Client.get_token(params)
    |> process_access_token_response(conn)
  end
  def get_access_token({:error, _term} = error, _params, _get_token_params), do: error

  defp process_access_token_response({:ok, %{token: %{other_params: %{"error" => error, "error_description" => error_description}}}}, conn),
    do: {:error, %{conn: conn, error: %CoherenceAssent.RequestError{message: error_description, error: error}}}
  defp process_access_token_response({:ok, client}, conn),
    do: {:ok, %{conn: conn, client: client}}
  defp process_access_token_response({:error, %OAuth2.Response{body: %{"error" => error}}}, conn),
    do: {:error, %{conn: conn, error: %CoherenceAssent.RequestError{message: error}}}
  defp process_access_token_response({:error, error}, conn),
    do: {:error, %{conn: conn, error: error}}

  @spec get_user({:ok, map} | {:error, term}, String.t | nil) :: {:ok, map} | {:error, term}
  def get_user({:ok, _map}, nil), do: raise "No user URL set"
  def get_user({:ok, %{conn: conn, client: client}}, user_url) do
    client
    |> OAuth2.Client.get(user_url)
    |> process_user_response(conn, client)
  end
  def get_user({:error, _term} = error, _user_url), do: error

  defp process_user_response({:ok, %OAuth2.Response{body: user}}, conn, client),
    do: {:ok, %{conn: conn, client: client, user: user}}
  defp process_user_response({:error, %OAuth2.Response{status_code: 401, body: _body}}, _conn, _client) do
    raise "Unauthorized token"
  end
  defp process_user_response({:error, %OAuth2.Error{reason: reason}}, _conn, _client) do
    raise "Error: #{inspect reason}"
  end

  defp gen_state() do
    24
    |> :crypto.strong_rand_bytes()
    |> :erlang.bitstring_to_list
    |> Enum.map(fn (x) -> :erlang.integer_to_binary(x, 16) end)
    |> Enum.join
    |> String.downcase
  end
end
