defmodule Helpdeskex.Repo.Migrations.CreateAttachments do
  use Ecto.Migration

  def change do
    create table(:attachments, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :ticket_id, references(:tickets, on_delete: :delete_all, type: :binary_id), null: false
      add :message_id, references(:ticket_messages, on_delete: :delete_all, type: :binary_id)
      add :file_url, :string, null: false
      add :file_type, :string
      add :file_name, :string
      add :uploaded_by_id, references(:users, type: :binary_id)

      timestamps(type: :utc_datetime)
    end

    create index(:attachments, [:ticket_id])
    create index(:attachments, [:message_id])
  end
end
