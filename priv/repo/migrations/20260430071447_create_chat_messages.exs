defmodule Helpdeskex.Repo.Migrations.CreateChatMessages do
  use Ecto.Migration

  def change do
    create table(:chat_messages, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :body, :text
      add :type, :string, null: false, default: "text"
      add :metadata, :text
      add :edited_at, :utc_datetime
      add :deleted_at, :utc_datetime

      add :conversation_id,
          references(:chat_conversations, type: :binary_id, on_delete: :delete_all),
          null: false

      add :sender_id, references(:users, type: :binary_id, on_delete: :nilify_all)

      add :reply_to_id, references(:chat_messages, type: :binary_id, on_delete: :nilify_all)

      timestamps(type: :utc_datetime)
    end

    create index(:chat_messages, [:conversation_id])
    create index(:chat_messages, [:sender_id])
    create index(:chat_messages, [:conversation_id, :inserted_at])
  end
end
