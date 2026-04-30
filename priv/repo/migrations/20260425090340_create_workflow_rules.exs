defmodule Helpdeskex.Repo.Migrations.CreateWorkflowRules do
  use Ecto.Migration

  def change do
    create table(:workflow_rules, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :tenant_id, references(:tenants, on_delete: :delete_all, type: :binary_id), null: false
      add :name, :string, null: false
      # ticket_created, ticket_updated
      add :trigger_event, :string, null: false
      add :conditions, :map
      add :actions, :map
      add :is_active, :boolean, default: true

      timestamps(type: :utc_datetime)
    end

    create index(:workflow_rules, [:tenant_id])
  end
end
