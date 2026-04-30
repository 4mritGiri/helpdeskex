defmodule Helpdeskex.Accounts.AuditLog do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "audit_logs" do
    field :action, :string
    field :resource_type, :string
    field :resource_id, :binary_id
    field :details, :map
    field :ip_address, :string
    field :user_agent, :string

    belongs_to :tenant, Helpdeskex.Accounts.Tenant
    belongs_to :user, Helpdeskex.Accounts.User

    timestamps(type: :utc_datetime, updated_at: false)
  end

  @doc false
  def changeset(audit_log, attrs) do
    audit_log
    |> cast(attrs, [
      :action,
      :resource_type,
      :resource_id,
      :details,
      :ip_address,
      :user_agent,
      :tenant_id,
      :user_id
    ])
    |> validate_required([:action, :resource_type, :tenant_id])
  end
end
