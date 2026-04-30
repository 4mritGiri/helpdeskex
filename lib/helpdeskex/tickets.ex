defmodule Helpdeskex.Tickets do
  @moduledoc """
  The Tickets context.
  """

  import Ecto.Query, warn: false
  alias Helpdeskex.Repo

  alias Helpdeskex.Tickets.Ticket
  alias Helpdeskex.Tickets.TicketStatus
  alias Helpdeskex.Tickets.TicketPriority
  alias Helpdeskex.Tickets.TicketMessage
  alias Helpdeskex.Tickets.WorkflowRule
  alias Helpdeskex.Tickets.TicketSla
  alias Helpdeskex.Tickets.SlaPolicy

  @topic "tickets"

  def subscribe do
    Phoenix.PubSub.subscribe(Helpdeskex.PubSub, @topic)
  end

  defp broadcast({:ok, ticket}, event) do
    ticket = Repo.preload(ticket, [:status, :priority, :requester, :assigned_to, :sla, :messages])
    Phoenix.PubSub.broadcast(Helpdeskex.PubSub, @topic, {event, ticket})
    {:ok, ticket}
  end

  defp broadcast({:error, _} = error, _event), do: error

  # --- Tickets ---

  def list_tickets(tenant_id) do
    Repo.all(
      from t in Ticket,
        where: t.tenant_id == ^tenant_id,
        preload: [:status, :priority, :requester, :assigned_to, :sla, :messages]
    )
  end

  def get_ticket!(id),
    do:
      Repo.get!(Ticket, id)
      |> Repo.preload([:status, :priority, :requester, :assigned_to, :sla, :messages])

  def create_ticket(attrs \\ %{}) do
    _tenant_id = attrs["tenant_id"] || attrs[:tenant_id]

    # Build a preliminary struct to check conditions
    temp_ticket = %Ticket{} |> Ticket.changeset(attrs) |> Ecto.Changeset.apply_changes()

    # Apply workflows to modify the ticket (e.g. auto-set priority)
    final_ticket = apply_workflows(temp_ticket, "ticket_created")

    final_ticket
    |> Repo.insert()
    |> case do
      {:ok, ticket} ->
        setup_ticket_sla(ticket)

        Helpdeskex.Accounts.log_action(%{
          tenant_id: ticket.tenant_id,
          user_id: ticket.requester_id,
          action: "create",
          resource_type: "tickets",
          resource_id: ticket.id,
          details: %{"subject" => ticket.subject}
        })

        {:ok, ticket}

      error ->
        error
    end
    |> broadcast(:ticket_created)
  end

  defp setup_ticket_sla(ticket) do
    # Find a policy for this tenant (or use a default)
    policy = Repo.one(from p in SlaPolicy, where: p.tenant_id == ^ticket.tenant_id, limit: 1)

    if policy do
      # Calculate response_by based on priority SLA hours (from seeds) or policy
      # For now, let's use the TicketPriority sla_hours as minutes for testing visibility
      priority = Repo.get(TicketPriority, ticket.priority_id)
      minutes = ((priority && priority.sla_hours) || 24) * 60

      response_by = DateTime.utc_now() |> DateTime.add(minutes, :minute)

      %TicketSla{}
      |> TicketSla.changeset(%{
        ticket_id: ticket.id,
        sla_policy_id: policy.id,
        response_by: response_by,
        status: "active"
      })
      |> Repo.insert()
    end
  end

  def change_ticket(%Ticket{} = ticket, attrs \\ %{}) do
    Ticket.changeset(ticket, attrs)
  end

  def update_ticket(%Ticket{} = ticket, attrs) do
    ticket
    |> Ticket.changeset(attrs)
    |> Repo.update()
    |> case do
      {:ok, updated_ticket} ->
        # Log the update (basic version, could diff changesets)
        Helpdeskex.Accounts.log_action(%{
          tenant_id: updated_ticket.tenant_id,
          action: "update",
          resource_type: "tickets",
          resource_id: updated_ticket.id,
          details: %{"changes" => attrs}
        })

        {:ok, updated_ticket}

      error ->
        error
    end
    |> broadcast(:ticket_updated)
  end

  # --- Ticket Statuses ---

  def list_ticket_statuses(tenant_id) do
    Repo.all(from s in TicketStatus, where: s.tenant_id == ^tenant_id, order_by: s.order_index)
  end

  def create_ticket_status(attrs \\ %{}) do
    %TicketStatus{}
    |> TicketStatus.changeset(attrs)
    |> Repo.insert()
  end

  # --- Ticket Priorities ---

  def list_ticket_priorities(tenant_id) do
    Repo.all(from p in TicketPriority, where: p.tenant_id == ^tenant_id)
  end

  def create_ticket_priority(attrs \\ %{}) do
    %TicketPriority{}
    |> TicketPriority.changeset(attrs)
    |> Repo.insert()
  end

  # --- Ticket Messages ---

  def list_ticket_messages(ticket_id) do
    Repo.all(
      from m in TicketMessage,
        where: m.ticket_id == ^ticket_id,
        order_by: [asc: m.inserted_at],
        preload: [:sender]
    )
  end

  def create_ticket_message(attrs \\ %{}) do
    %TicketMessage{}
    |> TicketMessage.changeset(attrs)
    |> Repo.insert()
  end

  def change_ticket_message(%TicketMessage{} = message, attrs \\ %{}) do
    TicketMessage.changeset(message, attrs)
  end

  # --- Workflow Engine ---

  def list_active_workflow_rules(tenant_id, trigger_event) do
    Repo.all(
      from w in WorkflowRule,
        where:
          w.tenant_id == ^tenant_id and w.trigger_event == ^trigger_event and w.is_active == true
    )
  end

  def apply_workflows(ticket, trigger_event) do
    rules = list_active_workflow_rules(ticket.tenant_id, trigger_event)

    Enum.reduce(rules, ticket, fn rule, acc_ticket ->
      if matches_conditions?(acc_ticket, rule.conditions) do
        apply_actions(acc_ticket, rule.actions)
      else
        acc_ticket
      end
    end)
  end

  defp matches_conditions?(ticket, conditions) do
    # Simple match: check if ticket attributes match the condition map
    # e.g. %{"subject_contains" => "login"}
    Enum.all?(conditions, fn {key, value} ->
      case key do
        "subject_contains" ->
          String.contains?(String.downcase(ticket.subject || ""), String.downcase(value))

        "priority_id" ->
          ticket.priority_id == value

        _ ->
          true
      end
    end)
  end

  defp apply_actions(ticket, actions) do
    # Simple action: update ticket attributes from the action map
    # e.g. %{"priority_name" => "urgent"}
    Enum.reduce(actions, ticket, fn {key, value}, acc ->
      case key do
        "set_priority_by_name" ->
          priority =
            Repo.get_by(Helpdeskex.Tickets.TicketPriority, tenant_id: acc.tenant_id, name: value)

          if priority, do: %{acc | priority_id: priority.id}, else: acc

        "set_assigned_to" ->
          %{acc | assigned_to_id: value}

        _ ->
          acc
      end
    end)
  end
end
