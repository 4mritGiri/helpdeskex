defmodule Helpdeskex.Accounts.Team do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "teams" do
    field :name, :string
    field :description, :string

    belongs_to :tenant, Helpdeskex.Accounts.Tenant
    many_to_many :users, Helpdeskex.Accounts.User, join_through: "team_members"

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(team, attrs) do
    team
    |> cast(attrs, [:name, :description, :tenant_id])
    |> validate_required([:name, :tenant_id])
    |> unique_constraint([:tenant_id, :name])
  end
end
