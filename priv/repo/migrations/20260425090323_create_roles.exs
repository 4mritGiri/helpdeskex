defmodule Helpdeskex.Repo.Migrations.CreateRoles do
  use Ecto.Migration

  def change do
    create table(:roles, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :tenant_id, references(:tenants, on_delete: :delete_all, type: :binary_id), null: false
      add :name, :string, null: false
      add :permissions, :map

      timestamps(type: :utc_datetime)
    end

    create index(:roles, [:tenant_id])
    create unique_index(:roles, [:tenant_id, :name])
  end
end
