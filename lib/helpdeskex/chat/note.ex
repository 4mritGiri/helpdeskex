defmodule Helpdeskex.Chat.Note do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "chat_notes" do
    field :body, :string
    field :attachments, :map
    field :conversation_id, :binary_id
    field :created_by_id, :binary_id

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(note, attrs) do
    note
    |> cast(attrs, [:body, :attachments])
    |> validate_required([:body])
  end
end
