defmodule Helpdeskex.Repo.Migrations.CreateSlaPolicies do
  use Ecto.Migration

  def change do
    create table(:sla_policies, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :tenant_id, references(:tenants, on_delete: :delete_all, type: :binary_id), null: false
      add :name, :string, null: false
      add :response_time_minutes, :integer
      add :resolution_time_minutes, :integer

      timestamps(type: :utc_datetime)
    end

    create index(:sla_policies, [:tenant_id])
  end
end
