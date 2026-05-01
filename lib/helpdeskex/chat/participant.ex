defmodule Helpdeskex.Chat.Participant do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "chat_participants" do
    field :nickname, :string
    field :role, :string, default: "member"
    field :last_read_at, :utc_datetime

    belongs_to :conversation, Helpdeskex.Chat.Conversation
    belongs_to :user, Helpdeskex.Accounts.User

    timestamps(type: :utc_datetime)
  end

  def changeset(participant, attrs) do
    participant
    |> cast(attrs, [:role, :last_read_at, :conversation_id, :user_id, :nickname])
    |> validate_required([:conversation_id, :user_id])
    |> validate_inclusion(:role, ["member", "admin"])
    |> unique_constraint([:conversation_id, :user_id])
  end
end
