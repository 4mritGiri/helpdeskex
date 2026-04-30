defmodule Helpdeskex.Repo.Migrations.CreateChatTodos do
  use Ecto.Migration

  def change do
    create table(:chat_todos, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :title, :string
      add :is_completed, :boolean, default: false, null: false
      add :conversation_id, references(:chat_conversations, on_delete: :nothing, type: :binary_id)
      add :created_by_id, references(:users, on_delete: :nothing, type: :binary_id)

      timestamps(type: :utc_datetime)
    end

    create index(:chat_todos, [:conversation_id])
    create index(:chat_todos, [:created_by_id])
  end
end
