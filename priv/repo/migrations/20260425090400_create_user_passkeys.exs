defmodule Helpdeskex.Repo.Migrations.CreateUserPasskeys do
  use Ecto.Migration

  def change do
    create table(:user_passkeys, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, on_delete: :delete_all, type: :binary_id), null: false
      add :external_id, :binary, null: false
      add :public_key, :binary, null: false
      add :nickname, :string
      add :sign_count, :integer, default: 0

      timestamps(type: :utc_datetime)
    end

    create index(:user_passkeys, [:user_id])
    create unique_index(:user_passkeys, [:external_id])
  end
end
