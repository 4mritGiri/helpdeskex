defmodule Helpdeskex.Chat.MessageStatus do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "chat_message_statuses" do
    field :status, :string, default: "delivered"

    belongs_to :message, Helpdeskex.Chat.Message
    belongs_to :user, Helpdeskex.Accounts.User

    timestamps(type: :utc_datetime)
  end

  def changeset(status, attrs) do
    status
    |> cast(attrs, [:status, :message_id, :user_id])
    |> validate_required([:message_id, :user_id])
    |> validate_inclusion(:status, ["delivered", "read"])
    |> unique_constraint([:message_id, :user_id])
  end
end
