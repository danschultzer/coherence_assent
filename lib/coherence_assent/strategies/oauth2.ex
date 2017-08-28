defmodule CoherenceAssent.Strategies.OAuth2 do
  @moduledoc """
  OAuth 2.0 strategy.
  """

  @doc false
  def authorize_url(conn: conn, config: config) do
    state        = gen_state()
    redirect_uri = config[:redirect_uri]
    params       = authorization_params(config, state, redirect_uri)

    url          = config
                   |> OAuth2.Client.new()
                   |> OAuth2.Client.authorize_url!(params)
    conn         = Plug.Conn.put_session(conn, "coherence_assent.state", state)

    {:ok, %{conn: conn, url: url}}
  end

  defp authorization_params(config, state, redirect_uri) do
    Keyword.get(config, :authorization_params, []) ++ [state: state, redirect_uri: redirect_uri]
  end

  @doc false
  def callback(conn: conn, config: config, params: params) do
    client = config
             |> OAuth2.Client.new()

    {:ok, %{conn: conn, client: client}}
    |> check_conn(params)
    |> get_access_token(params)
    |> get_user(config)
  end

  def check_conn({:ok, %{conn: conn}}, %{"error" => _} = params) do
    conn = Plug.Conn.delete_session(conn, "coherence_assent.state")

    {:error, %{conn: conn,
               error: %CoherenceAssent.CallbackError{
                 message: params["error_description"] || params["error_reason"] || params["error"],
                 error: params["error"],
                 error_uri: params["error_uri"]}}}
  end
  def check_conn({:ok, %{conn: conn, client: client}}, %{"code" => _code} = params) do
    state = Plug.Conn.get_session(conn, "coherence_assent.state")
    conn = Plug.Conn.delete_session(conn, "coherence_assent.state")

    case params["state"] do
      ^state -> {:ok, %{conn: conn, client: client}}
      _      -> {:error, %{conn: conn, error: %CoherenceAssent.CallbackCSRFError{}}}
    end
  end

  def get_access_token({:ok, %{conn: conn, client: client}}, %{"code" => code, "redirect_uri" => redirect_uri}) do
    client
    |> OAuth2.Client.get_token(code: code,
                               client_secret: client.client_secret,
                               redirect_uri: redirect_uri)
    |> process_access_token_response(conn)
  end
  def get_access_token({:error, _error} = error, _params), do: error

  defp process_access_token_response({:ok, %{token: %{other_params: %{"error" => error, "error_description" => error_description}}}}, conn),
    do: {:error, %{conn: conn, error: %CoherenceAssent.RequestError{message: error_description, error: error}}}
  defp process_access_token_response({:ok, client}, conn),
    do: {:ok, %{conn: conn, client: client}}
  defp process_access_token_response({:error, %OAuth2.Response{body: %{"error" => error}}}, conn),
    do: {:error, %{conn: conn, error: %CoherenceAssent.RequestError{message: error}}}
  defp process_access_token_response({:error, error}, conn),
    do: {:error, %{conn: conn, error: error}}

  def get_user({:ok, %{conn: conn, client: client}}, config) do
    client
    |> OAuth2.Client.get(config[:user_url] || raise "No user URL set")
    |> process_user_response(conn, client)
  end
  def get_user({:error, _} = error, _config), do: error

  defp process_user_response({:ok, %OAuth2.Response{body: user}}, conn, client),
    do: {:ok, %{conn: conn, client: client, user: user}}
  defp process_user_response({:error, %OAuth2.Response{status_code: 401, body: body}}, _conn, _client) do
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
