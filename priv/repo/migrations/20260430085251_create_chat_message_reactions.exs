defmodule Helpdeskex.Repo.Migrations.CreateChatMessageReactions do
  use Ecto.Migration

  def change do
    create table(:chat_message_reactions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :emoji, :string
      add :message_id, references(:chat_messages, on_delete: :nothing, type: :binary_id)
      add :user_id, references(:users, on_delete: :nothing, type: :binary_id)

      timestamps(type: :utc_datetime)
    end

    create index(:chat_message_reactions, [:message_id])
    create index(:chat_message_reactions, [:user_id])
  end
end
