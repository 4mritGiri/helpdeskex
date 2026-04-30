defmodule Helpdeskex.Repo.Migrations.CreateTicketStatuses do
  use Ecto.Migration

  def change do
    create table(:ticket_statuses, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :tenant_id, references(:tenants, on_delete: :delete_all, type: :binary_id), null: false
      add :name, :string, null: false
      add :order_index, :integer, default: 0

      timestamps(type: :utc_datetime)
    end

    create index(:ticket_statuses, [:tenant_id])
    create unique_index(:ticket_statuses, [:tenant_id, :name])
  end
end
