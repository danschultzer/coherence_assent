defmodule CoherenceAssent.Schema do
  @moduledoc """
  Add CoherenceAssent support to a User schema module.

  Add `use CoherenceAssent.Schema` to your User module to add a number of
  Module functions and helpers.

  The `coherence_assent_schema/0` macro is used to add schema fields to the User models schema.

  ## Examples:
      defmodule MyProject.User do
        use MyProject.Web, :model

        use Coherence.Schema
        use CoherenceAssent.Schema

        schema "users" do
          field :name, :string
          field :email, :string
          coherence_schema
          coherence_assent_schema
          timestamps
        end

        @required_fields ~w(name email)
        @optional_fields ~w() ++ coherence_fields

        def changeset(model, params \\ %{}) do
          model
          |> cast(params, @required_fields, @optional_fields)
          |> unique_constraint(:email)
          |> validate_coherence_assent(params)
        end

        def changeset(model, params, :password) do
          model
          |> cast(params, ~w(password password_confirmation reset_password_token reset_password_sent_at))
          |> validate_coherence_password_reset(params)
        end
      end
  """
  defmacro __using__(_opts \\ []) do
    quote do
      import unquote(__MODULE__)

      alias CoherenceAssent.UserIdentities.UserIdentity

      def validate_coherence_assent(changeset, %{"user_identity_provider" => provider, "user_identity_uid" => uid} = params) do
        user_identity = %UserIdentity{provider: provider, uid: uid}

        changeset
        |> confirm(Map.get(params, "unconfirmed", false))
        |> Ecto.Changeset.put_assoc(:user_identities, [user_identity])
      end
      def validate_coherence_assent(changeset, params) do
        user = changeset.data
               |> CoherenceAssent.repo.preload(:user_identities)

        authenticatable_with_identities = Coherence.Config.has_option(:authenticatable) &&
                                          length(user.user_identities) > 0
        validate_coherence_assent(changeset,
                                  params,
                                  authenticatable_with_identities)
      end

      defp confirm(changeset, false) do
        Ecto.Changeset.change(changeset, %{confirmed_at: Ecto.DateTime.utc, confirmation_token: nil})
      end
      defp confirm(changeset, _), do: changeset

      defp validate_coherence_assent(%{data: %{password_hash: nil}} = changeset, _params, true),
        do: changeset
      defp validate_coherence_assent(changeset, params, _authenticatable_with_identities),
        do: validate_coherence(changeset, params)
    end
  end

  @doc """
  Add configure schema fields.
  """
  defmacro coherence_assent_schema do
    quote do
      has_many :user_identities, CoherenceAssent.UserIdentities.UserIdentity, foreign_key: :user_id, on_delete: :delete_all
    end
  end
end
