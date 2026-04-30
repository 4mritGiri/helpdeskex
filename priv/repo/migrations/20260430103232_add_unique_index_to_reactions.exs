defmodule Helpdeskex.Repo.Migrations.AddUniqueIndexToReactions do
  use Ecto.Migration

  def change do
    create unique_index(:chat_message_reactions, [:message_id, :user_id, :emoji])
  end
end
