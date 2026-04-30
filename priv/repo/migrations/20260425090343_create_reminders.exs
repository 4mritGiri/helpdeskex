defmodule Helpdeskex.Repo.Migrations.CreateReminders do
  use Ecto.Migration

  def change do
    create table(:reminders, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, on_delete: :delete_all, type: :binary_id), null: false
      add :ticket_id, references(:tickets, on_delete: :delete_all, type: :binary_id)
      add :remind_at, :utc_datetime, null: false
      add :message, :string
      add :is_completed, :boolean, default: false

      timestamps(type: :utc_datetime)
    end

    create index(:reminders, [:user_id])
    create index(:reminders, [:remind_at])
  end
end
