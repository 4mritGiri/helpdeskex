defmodule Helpdeskex.Tickets.TicketPriority do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "ticket_priorities" do
    field :name, :string
    field :sla_hours, :integer, default: 24

    belongs_to :tenant, Helpdeskex.Accounts.Tenant
    has_many :tickets, Helpdeskex.Tickets.Ticket, foreign_key: :priority_id

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(ticket_priority, attrs) do
    ticket_priority
    |> cast(attrs, [:name, :sla_hours, :tenant_id])
    |> validate_required([:name, :tenant_id])
    |> unique_constraint([:tenant_id, :name])
  end
end
