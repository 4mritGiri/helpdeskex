defmodule Helpdeskex.Accounts.UserPasskey do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "user_passkeys" do
    field :external_id, :binary
    field :public_key, :binary
    field :nickname, :string
    field :sign_count, :integer, default: 0

    belongs_to :user, Helpdeskex.Accounts.User

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(user_passkey, attrs) do
    user_passkey
    |> cast(attrs, [:external_id, :public_key, :nickname, :sign_count, :user_id])
    |> validate_required([:external_id, :public_key, :user_id])
    |> unique_constraint(:external_id)
  end
end
