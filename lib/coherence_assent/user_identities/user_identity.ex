defmodule CoherenceAssent.UserIdentities.UserIdentity do
  @moduledoc false

  use Ecto.Schema

  @schema_name Application.get_env(:coherence_assent, :user_identity_schema_name, "user_identities")

  schema @schema_name do
    belongs_to :user, Coherence.Config.user_schema

    field :provider,     :string,     null: false
    field :uid,          :string,    null: false

    timestamps(updated_at: false)
  end
end
