defmodule Helpdeskex.Repo.Migrations.CreateUsers do
  use Ecto.Migration

  def change do
    create table(:users, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :tenant_id, references(:tenants, on_delete: :delete_all, type: :binary_id), null: false
      add :email, :string, null: false
      add :password_hash, :string, null: false
      add :full_name, :string
      add :is_active, :boolean, default: true, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:users, [:tenant_id])
    create unique_index(:users, [:tenant_id, :email])
  end
end
