defmodule Helpdeskex.Tickets.TicketMessage do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "ticket_messages" do
    field :body, :string
    field :message_type, :string, default: "public"

    belongs_to :ticket, Helpdeskex.Tickets.Ticket
    belongs_to :sender, Helpdeskex.Accounts.User

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(ticket_message, attrs) do
    ticket_message
    |> cast(attrs, [:body, :message_type, :ticket_id, :sender_id])
    |> validate_required([:body, :ticket_id, :sender_id])
  end
end
