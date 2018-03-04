defmodule CoherenceAssent.Callback do
  @moduledoc false

  alias CoherenceAssent.UserIdentities
  alias Coherence.ControllerHelpers, as: Helpers
  alias Coherence.Schemas

  @doc false
  def handler(current_user, provider, user) do
    {:ok, current_user}
    |> check_current_user(provider, user)
    |> get_or_create_user(provider, user)
  end

  @doc false
  defp check_current_user({:ok, nil}, _provider, _params), do: {:ok, nil}
  defp check_current_user({:ok, current_user}, provider, %{"uid" => uid}) do
    case UserIdentities.create_identity(current_user, provider, uid) do
      {:ok, _user_identity}                  -> {:ok, current_user}
      {:error, %{errors: [uid_provider: _]}} -> {:error, :bound_to_different_user}
      {:error, error}                        -> {:error, error}
    end
  end

  @doc false
  defp get_or_create_user({:ok, nil}, provider, %{"uid" => uid} = user) do
    case UserIdentities.get_user_from_identity_params(provider, uid) do
      nil   -> insert_user_with_identity(user, provider, uid)
      user  -> {:ok, :user_loaded, user}
    end
  end
  defp get_or_create_user({:ok, current_user}, _provider, _user), do: {:ok, :identity_created, current_user}
  defp get_or_create_user({:error, error}, _provider, _user), do: {:error, error}

  @doc false
  defp insert_user_with_identity(registration_params, provider, uid) do
    login_field = Atom.to_string(Coherence.Config.login_field())

    case registration_params do
      %{^login_field => nil} ->
        {:error, :missing_login_field}
      %{^login_field => _login_field} ->
        user_schema = Coherence.Config.user_schema
        registration_params = registration_params
                              |> Map.merge(%{"user_identity_provider" => provider,
                                             "user_identity_uid" => uid})
        :registration
        |> Helpers.changeset(user_schema, user_schema.__struct__, registration_params)
        |> Schemas.create
        |> case do
            {:ok, user} -> {:ok, :user_created, user}
            response    -> response
           end
      _registration_params ->
        {:error, :missing_login_field}
    end
  end
end
