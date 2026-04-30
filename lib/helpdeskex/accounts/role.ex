defmodule Helpdeskex.Accounts.Role do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "roles" do
    field :name, :string
    field :permissions, :map, default: %{}

    belongs_to :tenant, Helpdeskex.Accounts.Tenant
    many_to_many :users, Helpdeskex.Accounts.User, join_through: "user_roles"

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(role, attrs) do
    role
    |> cast(attrs, [:name, :permissions, :tenant_id])
    |> validate_required([:name, :tenant_id])
    |> unique_constraint([:tenant_id, :name])
  end
end
