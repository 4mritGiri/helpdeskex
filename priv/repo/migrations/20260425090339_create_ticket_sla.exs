defmodule Helpdeskex.Repo.Migrations.CreateTicketSla do
  use Ecto.Migration

  def change do
    create table(:ticket_sla, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :ticket_id, references(:tickets, on_delete: :delete_all, type: :binary_id), null: false
      add :sla_policy_id, references(:sla_policies, type: :binary_id), null: false
      add :response_by, :utc_datetime
      add :resolve_by, :utc_datetime
      add :responded_at, :utc_datetime
      add :resolved_at, :utc_datetime
      # active, breached, achieved
      add :status, :string, default: "active"

      timestamps(type: :utc_datetime)
    end

    create index(:ticket_sla, [:ticket_id])
    create index(:ticket_sla, [:status])
  end
end
