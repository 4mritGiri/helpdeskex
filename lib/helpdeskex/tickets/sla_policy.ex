defmodule Helpdeskex.Tickets.SlaPolicy do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "sla_policies" do
    field :name, :string
    field :response_time_minutes, :integer
    field :resolution_time_minutes, :integer

    belongs_to :tenant, Helpdeskex.Accounts.Tenant

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(sla_policy, attrs) do
    sla_policy
    |> cast(attrs, [:name, :response_time_minutes, :resolution_time_minutes, :tenant_id])
    |> validate_required([:name, :tenant_id])
  end
end
