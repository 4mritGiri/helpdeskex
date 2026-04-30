defmodule Helpdeskex.Accounts.Notification do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "notifications" do
    field :title, :string
    field :body, :string
    field :link, :string
    field :is_read, :boolean, default: false
    field :type, :string, default: "info"

    belongs_to :user, Helpdeskex.Accounts.User

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(notification, attrs) do
    notification
    |> cast(attrs, [:title, :body, :link, :is_read, :type, :user_id])
    |> validate_required([:title, :user_id])
  end
end
