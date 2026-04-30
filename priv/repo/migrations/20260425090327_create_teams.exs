defmodule Helpdeskex.Repo.Migrations.CreateTeams do
  use Ecto.Migration

  def change do
    create table(:teams, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :tenant_id, references(:tenants, on_delete: :delete_all, type: :binary_id), null: false
      add :name, :string, null: false
      add :description, :text

      timestamps(type: :utc_datetime)
    end

    create index(:teams, [:tenant_id])
    create unique_index(:teams, [:tenant_id, :name])
  end
end
