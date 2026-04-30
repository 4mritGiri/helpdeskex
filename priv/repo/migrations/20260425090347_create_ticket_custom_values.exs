defmodule Helpdeskex.Repo.Migrations.CreateTicketCustomValues do
  use Ecto.Migration

  def change do
    create table(:ticket_custom_values, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :ticket_id, references(:tickets, on_delete: :delete_all, type: :binary_id), null: false

      add :custom_field_id, references(:custom_fields, on_delete: :delete_all, type: :binary_id),
        null: false

      add :value, :text

      timestamps(type: :utc_datetime)
    end

    create index(:ticket_custom_values, [:ticket_id])
    create index(:ticket_custom_values, [:custom_field_id])
    create unique_index(:ticket_custom_values, [:ticket_id, :custom_field_id])
  end
end
