defmodule Helpdeskex.Repo.Migrations.CreateAuditLogs do
  use Ecto.Migration

  def change do
    create table(:audit_logs, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :tenant_id, references(:tenants, on_delete: :delete_all, type: :binary_id), null: false
      add :user_id, references(:users, type: :binary_id)
      # create, update, delete, login, etc
      add :action, :string, null: false
      # tickets, users, etc
      add :resource_type, :string, null: false
      add :resource_id, :binary_id
      # jsonb for old/new values
      add :details, :map
      add :ip_address, :string
      add :user_agent, :text

      timestamps(type: :utc_datetime, updated_at: false)
    end

    create index(:audit_logs, [:tenant_id])
    create index(:audit_logs, [:user_id])
    create index(:audit_logs, [:resource_type, :resource_id])
  end
end
