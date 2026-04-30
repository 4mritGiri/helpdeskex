defmodule Helpdeskex.Repo.Migrations.CreateTicketAssignments do
  use Ecto.Migration

  def change do
    create table(:ticket_assignments, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :ticket_id, references(:tickets, on_delete: :delete_all, type: :binary_id), null: false
      add :assigned_to_id, references(:users, type: :binary_id)
      add :assigned_by_id, references(:users, type: :binary_id)
      add :team_id, references(:teams, type: :binary_id)

      timestamps(type: :utc_datetime)
    end

    create index(:ticket_assignments, [:ticket_id])
    create index(:ticket_assignments, [:assigned_to_id])
  end
end
