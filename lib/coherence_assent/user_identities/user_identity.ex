defmodule CoherenceAssent.UserIdentities.UserIdentity do
  @moduledoc false

  use Ecto.Schema

  schema "user_identities" do
    belongs_to :user, Coherence.Config.user_schema

    field :provider,     :string,     null: false
    field :uid,          :string,    null: false

    timestamps(updated_at: false)
  end
end
