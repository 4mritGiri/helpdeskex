defmodule Helpdeskex.Tickets.WorkflowRule do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "workflow_rules" do
    field :name, :string
    field :trigger_event, :string
    field :conditions, :map
    field :actions, :map
    field :is_active, :boolean, default: true

    belongs_to :tenant, Helpdeskex.Accounts.Tenant

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(workflow_rule, attrs) do
    workflow_rule
    |> cast(attrs, [:name, :trigger_event, :conditions, :actions, :is_active, :tenant_id])
    |> validate_required([:name, :trigger_event, :conditions, :actions, :tenant_id])
  end
end
