defmodule Helpdeskex.Repo.Migrations.CreateTicketPriorities do
  use Ecto.Migration

  def change do
    create table(:ticket_priorities, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :tenant_id, references(:tenants, on_delete: :delete_all, type: :binary_id), null: false
      add :name, :string, null: false
      add :sla_hours, :integer, default: 24

      timestamps(type: :utc_datetime)
    end

    create index(:ticket_priorities, [:tenant_id])
    create unique_index(:ticket_priorities, [:tenant_id, :name])
  end
end
