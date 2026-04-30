defmodule Helpdeskex.Repo.Migrations.CreateTickets do
  use Ecto.Migration

  def change do
    create table(:tickets, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :tenant_id, references(:tenants, on_delete: :delete_all, type: :binary_id), null: false
      add :subject, :string, null: false
      add :description, :text
      add :status_id, references(:ticket_statuses, type: :binary_id)
      add :priority_id, references(:ticket_priorities, type: :binary_id)
      add :requester_id, references(:users, type: :binary_id), null: false
      add :assigned_to_id, references(:users, type: :binary_id)
      add :team_id, references(:teams, type: :binary_id)
      add :due_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create index(:tickets, [:tenant_id])
    create index(:tickets, [:status_id])
    create index(:tickets, [:priority_id])
    create index(:tickets, [:requester_id])
    create index(:tickets, [:assigned_to_id])
    create index(:tickets, [:team_id])
  end
end
