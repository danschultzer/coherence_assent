defmodule CoherenceAssent.Strategy.OAuth2 do
  @moduledoc """
  OAuth 2.0 strategy.
  """

  @doc false
  @spec authorize_url(Conn.t, Keyword.t) :: {:ok, %{conn: Conn.t, url: String.t}}
  def authorize_url(conn, config) do
    state = gen_state()
    params = authorization_params(config, state: state, redirect_uri: config[:redirect_uri])
    url = config |> OAuth2.Client.new() |> OAuth2.Client.authorize_url!(params)
    conn = Plug.Conn.put_session(conn, "coherence_assent.state", state)

    {:ok, %{conn: conn, url: url}}
  end

  defp authorization_params(config, params) do
    config
    |> Keyword.get(:authorization_params, [])
    |> Keyword.merge(params)
  end

  @doc false
  @spec callback(Conn.t, Keyword.t, map) :: {:ok, %{conn: Conn.t, client: OAuth2.Client.t, user: map}} | {:error, %{conn: Conn.t, error: term}}
  def callback(conn, config, params) do
    client = OAuth2.Client.new(config)
    {conn, state} = retrieve_and_clear_state(conn)

    state
    |> check_state(client, params)
    |> get_access_token(config, params)
    |> get_user(config[:user_url])
    |> case do
      {:ok, user} -> {:ok, %{conn: conn, client: client, user: user}}
      {:error, error} -> {:error, %{conn: conn, error: error}}
    end
  end

  @doc false
  @spec check_state(String.t, OAuth2.Client.t, map) :: {:ok, %{client: OAuth2.Client.t}} | {:error, term}
  def check_state(_state, _client, %{"error" => _} = params) do
    message = params["error_description"] || params["error_reason"] || params["error"]
    error = params["error"]
    error_uri = params["error_uri"]

    {:error, %CoherenceAssent.CallbackError{message: message, error: error, error_uri: error_uri}}
  end
  def check_state(state, client, %{"code" => _code} = params) do
    case params["state"] do
      ^state -> {:ok, %{client: client}}
      _ -> {:error, %CoherenceAssent.CallbackCSRFError{}}
    end
  end

  @doc false
  @spec get_access_token({:ok, %{client: OAuth2.Client.t}} | {:error, map}, Keyword.t, map) :: {:ok, OAuth2.Client.t} | {:error, term}
  def get_access_token({:ok, %{client: client}}, config, %{"code" => code, "redirect_uri" => redirect_uri}) do
    params = authorization_params(config, code: code, client_secret: client.client_secret, redirect_uri: redirect_uri)

    client
    |> OAuth2.Client.get_token(params)
    |> process_access_token_response()
  end
  def get_access_token({:error, error}, _params, _token_params), do: {:error, error}

  defp process_access_token_response({:ok, %{token: %{other_params: %{"error" => error, "error_description" => error_description}}}}),
    do: {:error, %CoherenceAssent.RequestError{message: error_description, error: error}}
  defp process_access_token_response({:error, %OAuth2.Response{body: %{"error" => error}}}),
    do: {:error, %CoherenceAssent.RequestError{message: error}}
  defp process_access_token_response({:ok, client}),
    do: {:ok, client}
  defp process_access_token_response({:error, error}),
    do: {:error, error}

  @spec get_user({:ok, OAuth2.Client.t} | {:error, term}, String.t | nil) :: {:ok, map} | {:error, term}
  def get_user({:ok, _client}, nil),
    do: {:error, %CoherenceAssent.ConfigurationError{message: "No user URL set"}}
  def get_user({:ok, client}, user_url) do
    client
    |> OAuth2.Client.get(user_url)
    |> process_user_response()
  end
  def get_user({:error, error}, _user_url), do: {:error, error}

  defp process_user_response({:ok, %OAuth2.Response{body: user}}), do: {:ok, user}
  defp process_user_response({:error, %OAuth2.Response{status_code: 401}}),
    do: {:error, %CoherenceAssent.RequestError{message: "Unauthorized token"}}
  defp process_user_response({:error, error}), do: {:error, error}

  defp gen_state() do
    24
    |> :crypto.strong_rand_bytes()
    |> :erlang.bitstring_to_list()
    |> Enum.map(fn (x) -> :erlang.integer_to_binary(x, 16) end)
    |> Enum.join()
    |> String.downcase()
  end

  @spec retrieve_and_clear_state(Conn.t) :: {Plug.Conn.t, String.t | nil}
  def retrieve_and_clear_state(conn) do
    {Plug.Conn.delete_session(conn, "coherence_assent.state"),
     Plug.Conn.get_session(conn, "coherence_assent.state")}
  end
end
