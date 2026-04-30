defmodule Helpdeskex.Repo.Migrations.CreateChatConversations do
  use Ecto.Migration

  def change do
    create table(:chat_conversations, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string
      add :type, :string, null: false, default: "direct"
      add :avatar_url, :string
      add :tenant_id, references(:tenants, type: :binary_id, on_delete: :delete_all), null: false
      add :created_by_id, references(:users, type: :binary_id, on_delete: :nilify_all)

      timestamps(type: :utc_datetime)
    end

    create index(:chat_conversations, [:tenant_id])
    create index(:chat_conversations, [:created_by_id])
  end
end
