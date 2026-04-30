defmodule Helpdeskex.Accounts.Tenant do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "tenants" do
    field :name, :string
    field :plan, :string, default: "free"
    field :is_active, :boolean, default: true

    has_many :users, Helpdeskex.Accounts.User
    has_many :roles, Helpdeskex.Accounts.Role
    has_many :teams, Helpdeskex.Accounts.Team

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(tenant, attrs) do
    tenant
    |> cast(attrs, [:name, :plan, :is_active])
    |> validate_required([:name])
    |> unique_constraint(:name)
  end
end
