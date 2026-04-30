defmodule Helpdeskex.Repo.Migrations.CreateNotifications do
  use Ecto.Migration

  def change do
    create table(:notifications, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, on_delete: :delete_all, type: :binary_id), null: false
      add :title, :string, null: false
      add :body, :text
      add :link, :string
      add :is_read, :boolean, default: false
      # info, warning, error
      add :type, :string

      timestamps(type: :utc_datetime)
    end

    create index(:notifications, [:user_id])
    create index(:notifications, [:is_read])
  end
end
