defmodule Helpdeskex.Chat.Conversation do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "chat_conversations" do
    field :name, :string
    field :type, :string, default: "direct"
    field :avatar_url, :string

    belongs_to :tenant, Helpdeskex.Accounts.Tenant
    belongs_to :created_by, Helpdeskex.Accounts.User

    has_many :participants, Helpdeskex.Chat.Participant
    has_many :messages, Helpdeskex.Chat.Message

    has_many :users, through: [:participants, :user]

    timestamps(type: :utc_datetime)
  end

  def changeset(conversation, attrs) do
    conversation
    |> cast(attrs, [:name, :type, :avatar_url, :tenant_id, :created_by_id])
    |> validate_required([:type, :tenant_id])
    |> validate_inclusion(:type, ["direct", "group"])
  end
end
