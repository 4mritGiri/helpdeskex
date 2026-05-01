defmodule Helpdeskex.Repo.Migrations.AddNicknameToParticipants do
  use Ecto.Migration

  def change do
    alter table(:chat_participants) do
      add :nickname, :string
    end
  end
end
