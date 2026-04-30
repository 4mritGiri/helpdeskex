defmodule Helpdeskex.Chat.MessageReaction do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "chat_message_reactions" do
    field :emoji, :string
    belongs_to :message, Helpdeskex.Chat.Message
    belongs_to :user, Helpdeskex.Accounts.User

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(message_reaction, attrs) do
    message_reaction
    |> cast(attrs, [:emoji, :message_id, :user_id])
    |> validate_required([:emoji, :message_id, :user_id])
  end
end
