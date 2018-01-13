defmodule CoherenceAssent.UserIdentities do
  @moduledoc """
  The boundary for the UserIdentities system.
  """

  import Ecto.{Query, Changeset}, warn: false
  alias CoherenceAssent.UserIdentities.UserIdentity

  @doc """
  Gets a single access grant registered with an application.

  ## Examples

      iex> get_user_from_identity_params("github", "uid")
      %User{}

      iex> get_user_from_identity_params("github", "invalid_uid")
      ** nil

  """
  def get_user_from_identity_params(provider, uid) do
    UserIdentity
    |> CoherenceAssent.repo.get_by(provider: provider, uid: uid)
    |> get_user_from_identity
  end

  defp get_user_from_identity(nil), do: nil
  defp get_user_from_identity(identity) do
    identity
    |> CoherenceAssent.repo.preload(:user)
    |> Map.fetch(:user)
    |> case do
      {:ok, user} -> user
      :error       -> nil
    end
  end

  @doc """
  Creates a new user identity.

  ## Examples

      iex> create_identity(user, "github", 1)
      {:ok, %UserIdentity{}}

      iex> create_identity(user, "github", 1)
      {:error, %Ecto.Changeset{}}

  """
  def create_identity(%{id: _} = user, provider, uid) do
    %UserIdentity{user: user}
    |> new_identity_changeset(%{provider: provider, uid: uid})
    |> CoherenceAssent.repo.insert()
  end

  defp new_identity_changeset(%UserIdentity{} = identity, params) do
    identity
    |> cast(params, [:provider, :uid])
    |> assoc_constraint(:user)
    |> validate_required([:provider, :uid, :user])
    |> unique_constraint(:uid_provider, name: :user_identities_uid_provider_index)
  end

  @doc """
  Deletes identity from user.

  ## Examples

      iex> delete_identity_from_user(user, "github", 1)
      {:ok, %UserIdentity{}}

      iex> delete_identity_from_user(user, "github", 0)
      {:error, %Ecto.Changeset{}}

  """
  def delete_identity_from_user(%{id: user_id}, provider) do
    UserIdentity
    |> CoherenceAssent.repo.get_by(provider: provider, user_id: user_id)
    |> delete_identity()
  end

  defp delete_identity(%UserIdentity{} = identity) do
    identity
    |> delete_changeset()
    |> CoherenceAssent.repo.delete()
  end
  defp delete_identity(nil),
    do: {:ok, nil}

  defp delete_changeset(%UserIdentity{} = identity) do
    user = identity |> get_user_from_identity

    identity
    |> cast(%{}, [])
    |> validate_user_has_password_or_other_identity(user)
  end

  defp validate_user_has_password_or_other_identity(changeset, %{password_hash: nil} = user) do
    query = from i in UserIdentity, where: i.user_id == ^user.id, select: i.id

    count = query
    |> CoherenceAssent.repo.all()
    |> Enum.count

    case count > 1 do
      true -> changeset
      _    -> add_error(changeset, :user, "needs password")
    end
  end
  defp validate_user_has_password_or_other_identity(changeset, _user),
    do: changeset
end
