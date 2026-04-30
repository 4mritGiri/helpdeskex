defmodule Helpdeskex.Chat.Todo do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "chat_todos" do
    field :title, :string
    field :is_completed, :boolean, default: false
    field :conversation_id, :binary_id
    field :created_by_id, :binary_id

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(todo, attrs) do
    todo
    |> cast(attrs, [:title, :is_completed])
    |> validate_required([:title, :is_completed])
  end
end
