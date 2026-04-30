defmodule Helpdeskex.Repo.Migrations.CreateTicketMessages do
  use Ecto.Migration

  def change do
    create table(:ticket_messages, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :ticket_id, references(:tickets, on_delete: :delete_all, type: :binary_id), null: false
      add :sender_id, references(:users, type: :binary_id), null: false
      # public, private, system
      add :message_type, :string, default: "public"
      add :body, :text, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:ticket_messages, [:ticket_id])
    create index(:ticket_messages, [:sender_id])
  end
end
