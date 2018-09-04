defmodule CoherenceAssent.Controller do
  @moduledoc false
  use CoherenceWeb, :controller

  import Plug.Conn, only: [put_session: 3]
  import Phoenix.Naming, only: [humanize: 1]

  def callback_response({:ok, :user_created, user}, conn, _provider, _user_params, params) do
    conn
    |> send_confirmation(user)
    |> create_user_session(user)
    |> redirect_to(:registration_create, params)
  end
  def callback_response({:ok, _type, user}, conn, _provider, _user_params, params) do
    conn
    |> create_user_session(user)
    |> redirect_to(:session_create, params)
  end
  def callback_response({:error, :bound_to_different_user}, conn, provider, _user_params, _params) do
    conn
    |> put_flash(:error, CoherenceAssent.Messages.backend().account_already_bound_to_other_user(%{provider: humanize(provider)}))
    |> redirect(to: get_route(conn, :registration_path, :new))
  end
  def callback_response({:error, :missing_login_field}, conn, provider, user_params, _params) do
    conn
    |> put_session("coherence_assent_params", user_params)
    |> redirect(to: get_route(conn, :coherence_assent_registration_path, :add_login_field, [provider]))
  end
  def callback_response({:error, %Ecto.Changeset{} = changeset}, conn, _provider, user_params, params) do
    login_field = Coherence.Config.login_field

    case changeset do
      %{errors: [{^login_field, _}]} = changeset ->
        conn
        |> put_session("coherence_assent_params", user_params)
        |> CoherenceAssent.RegistrationController.add_login_field(params, changeset)
      %{errors: _errors} ->
        conn
        |> put_flash(:error, CoherenceAssent.Messages.backend().could_not_sign_in())
        |> redirect(to: Coherence.Config.logged_out_url(conn))
    end
  end

  def get_route(conn, path, action, params \\ []) do
    apply(router_helpers(), path, [conn, action] ++ params)
  end

  defp send_confirmation(conn, user) do
    cond do
      not Coherence.Config.user_schema.confirmable?() -> conn
      not Coherence.Config.user_schema.confirmed?(user) -> Coherence.Controller.send_confirmation(conn, user, Coherence.Config.user_schema)
      true -> conn
    end
  end

  defp create_user_session(conn, user) do
    Coherence.Controller.login_user(conn, user)
  end
end
