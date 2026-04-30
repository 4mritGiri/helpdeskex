defmodule Helpdeskex.Chat.Attachment do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "chat_attachments" do
    field :filename, :string
    field :content_type, :string
    field :size, :integer
    field :path, :string

    belongs_to :message, Helpdeskex.Chat.Message

    timestamps(type: :utc_datetime)
  end

  def changeset(attachment, attrs) do
    attachment
    |> cast(attrs, [:filename, :content_type, :size, :path, :message_id])
    |> validate_required([:filename, :path, :message_id])
  end
end
