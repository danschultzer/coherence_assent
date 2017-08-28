defmodule <%= inspect mod %> do
  use Ecto.Migration

  def change do
    create table(:user_identities) do
      add :user_id,           :integer, null: false
      add :provider,          :string,  null: false
      add :uid,               :string,  null: false

      timestamps(updated_at: false)
    end

    create unique_index(:user_identities, [:uid, :provider], name: :user_identities_uid_provider_index)
  end
end
