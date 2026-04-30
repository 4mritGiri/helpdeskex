defmodule Helpdeskex.Repo.Migrations.CreateChatAttachments do
  use Ecto.Migration

  def change do
    create table(:chat_attachments, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :filename, :string, null: false
      add :content_type, :string
      add :size, :integer
      add :path, :string, null: false

      add :message_id,
          references(:chat_messages, type: :binary_id, on_delete: :delete_all),
          null: false

      timestamps(type: :utc_datetime)
    end

    create index(:chat_attachments, [:message_id])
  end
end
