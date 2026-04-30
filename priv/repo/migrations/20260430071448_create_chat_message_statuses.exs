defmodule Helpdeskex.Repo.Migrations.CreateChatMessageStatuses do
  use Ecto.Migration

  def change do
    create table(:chat_message_statuses, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :status, :string, null: false, default: "delivered"

      add :message_id,
          references(:chat_messages, type: :binary_id, on_delete: :delete_all),
          null: false

      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime, updated_at: :updated_at)
    end

    create index(:chat_message_statuses, [:message_id])
    create index(:chat_message_statuses, [:user_id])
    create unique_index(:chat_message_statuses, [:message_id, :user_id])
  end
end
