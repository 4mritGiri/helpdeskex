defmodule Helpdeskex.Tickets.Ticket do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "tickets" do
    field :subject, :string
    field :description, :string
    field :due_at, :utc_datetime

    belongs_to :tenant, Helpdeskex.Accounts.Tenant
    belongs_to :status, Helpdeskex.Tickets.TicketStatus
    belongs_to :priority, Helpdeskex.Tickets.TicketPriority
    belongs_to :requester, Helpdeskex.Accounts.User, foreign_key: :requester_id
    belongs_to :assigned_to, Helpdeskex.Accounts.User, foreign_key: :assigned_to_id
    belongs_to :team, Helpdeskex.Accounts.Team
    has_many :messages, Helpdeskex.Tickets.TicketMessage
    has_one :sla, Helpdeskex.Tickets.TicketSla

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(ticket, attrs) do
    ticket
    |> cast(attrs, [
      :subject,
      :description,
      :due_at,
      :tenant_id,
      :status_id,
      :priority_id,
      :requester_id,
      :assigned_to_id,
      :team_id
    ])
    |> validate_required([:subject, :tenant_id, :requester_id])
  end
end
