defmodule Helpdeskex.Tickets.TicketSla do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "ticket_sla" do
    field :response_by, :utc_datetime
    field :resolve_by, :utc_datetime
    field :responded_at, :utc_datetime
    field :resolved_at, :utc_datetime
    field :status, :string, default: "active"

    belongs_to :ticket, Helpdeskex.Tickets.Ticket
    belongs_to :sla_policy, Helpdeskex.Tickets.SlaPolicy

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(ticket_sla, attrs) do
    ticket_sla
    |> cast(attrs, [
      :response_by,
      :resolve_by,
      :responded_at,
      :resolved_at,
      :status,
      :ticket_id,
      :sla_policy_id
    ])
    |> validate_required([:ticket_id, :sla_policy_id])
  end
end
