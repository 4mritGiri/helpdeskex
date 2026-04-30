defmodule Helpdeskex.Chat.Message do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "chat_messages" do
    field :body, :string
    field :type, :string, default: "text"
    field :metadata, :string
    field :edited_at, :utc_datetime
    field :deleted_at, :utc_datetime

    belongs_to :conversation, Helpdeskex.Chat.Conversation
    belongs_to :sender, Helpdeskex.Accounts.User
    belongs_to :reply_to, Helpdeskex.Chat.Message

    has_many :statuses, Helpdeskex.Chat.MessageStatus
    has_many :attachments, Helpdeskex.Chat.Attachment

    timestamps(type: :utc_datetime)
  end

  def changeset(message, attrs) do
    message
    |> cast(attrs, [
      :body,
      :type,
      :metadata,
      :edited_at,
      :deleted_at,
      :conversation_id,
      :sender_id,
      :reply_to_id
    ])
    |> validate_required([:conversation_id, :sender_id])
    |> validate_inclusion(:type, ["text", "image", "file", "system"])
  end
end
