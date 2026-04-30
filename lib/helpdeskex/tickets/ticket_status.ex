defmodule Helpdeskex.Tickets.TicketStatus do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "ticket_statuses" do
    field :name, :string
    field :order_index, :integer, default: 0

    belongs_to :tenant, Helpdeskex.Accounts.Tenant
    has_many :tickets, Helpdeskex.Tickets.Ticket, foreign_key: :status_id

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(ticket_status, attrs) do
    ticket_status
    |> cast(attrs, [:name, :order_index, :tenant_id])
    |> validate_required([:name, :tenant_id])
    |> unique_constraint([:tenant_id, :name])
  end
end
