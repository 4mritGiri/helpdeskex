defmodule Helpdeskex.Repo.Migrations.CreateChatNotes do
  use Ecto.Migration

  def change do
    create table(:chat_notes, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :body, :text
      add :attachments, :map
      add :conversation_id, references(:chat_conversations, on_delete: :nothing, type: :binary_id)
      add :created_by_id, references(:users, on_delete: :nothing, type: :binary_id)

      timestamps(type: :utc_datetime)
    end

    create index(:chat_notes, [:conversation_id])
    create index(:chat_notes, [:created_by_id])
  end
end
