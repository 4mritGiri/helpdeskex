defmodule Helpdeskex.Repo.Migrations.CreateChatParticipants do
  use Ecto.Migration

  def change do
    create table(:chat_participants, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :role, :string, null: false, default: "member"
      add :last_read_at, :utc_datetime

      add :conversation_id,
          references(:chat_conversations, type: :binary_id, on_delete: :delete_all),
          null: false

      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:chat_participants, [:conversation_id])
    create index(:chat_participants, [:user_id])
    create unique_index(:chat_participants, [:conversation_id, :user_id])
  end
end
