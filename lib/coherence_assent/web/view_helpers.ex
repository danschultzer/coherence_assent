defmodule CoherenceAssent.ViewHelpers do
  @moduledoc false

  defmacro __using__(opts \\ []) do
    quote do
      @spec oauth_links(conn):: String.t
      def oauth_links(conn), do: oauth_links(conn, nil)

      @spec oauth_links(conn, Ecto.Schema.t | Ecto.Changeset.t):: String.t
      def oauth_links(conn, current_user) do
        CoherenceAssent.providers!()
        |> Keyword.keys()
        |> Enum.map(fn(provider) -> oauth_link(conn, provider, current_user) end)
        |> concat([])
      end

      @spec oauth_link(conn, String.t | atom, Ecto.Schema.t | Ecto.Changeset.t | nil) :: String.t
      def oauth_link(conn, provider, nil), do: oauth_signin_link(conn, provider)
      def oauth_link(conn, provider, current_user) do
        CoherenceAssent.UserIdentities.UserIdentity
        |> CoherenceAssent.repo.get_by(provider: Atom.to_string(provider), user_id: current_user.id)
        |> case do
             nil -> oauth_signin_link(conn, provider)
             _   -> oauth_remove_link(conn, provider)
           end
      end

      defp oauth_signin_link(conn, provider) do
       %{provider: humanize(provider)}
       |> CoherenceAssent.Messages.backend().login_with_provider()
       |> link(to: unquote(opts)[:helpers].coherence_assent_auth_path(conn, :index, provider))
      end

      defp oauth_remove_link(conn, provider) do
       %{provider: humanize(provider)}
       |> CoherenceAssent.Messages.backend().remove_provider_authentication()
       |> link(to: unquote(opts)[:helpers].coherence_assent_auth_path(conn, :delete, provider), method: :delete)
      end
    end
  end
end
