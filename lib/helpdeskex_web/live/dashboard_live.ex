defmodule HelpdeskexWeb.DashboardLive do
  use HelpdeskexWeb, :live_view

  on_mount {HelpdeskexWeb.Auth.LiveHooks, :require_authenticated_user}

  alias Helpdeskex.Tickets
  alias Helpdeskex.Accounts
  alias HelpdeskexWeb.UserEmail
  alias Helpdeskex.Mailer

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Tickets.subscribe()
      Accounts.subscribe(socket.assigns.current_user.id)
      # Tick every second for SLA countdowns
      :timer.send_interval(1000, self(), :tick)
    end

    tenant_id = get_first_tenant_id()
    user_id = socket.assigns.current_user.id
    notifications = Accounts.list_unread_notifications(user_id)

    {tickets, statuses} =
      if tenant_id do
        {Tickets.list_tickets(tenant_id), Tickets.list_ticket_statuses(tenant_id)}
      else
        {[], []}
      end

    priorities = if tenant_id, do: Tickets.list_ticket_priorities(tenant_id), else: []
    stats = compute_stats(tickets)

    passkeys = Accounts.list_user_passkeys(user_id)

    {:ok,
     socket
     |> assign(:page_title, "Dashboard · HelpdeskEx")
     |> assign(:tickets, tickets)
     |> assign(:statuses, statuses)
     |> assign(:priorities, priorities)
     |> assign(:stats, stats)
     |> assign(:passkeys, passkeys)
     |> assign(:selected_ticket, nil)
     # Added current_view
     |> assign(:current_view, "kanban")
     |> assign(:chat_messages, [
       %{
         id: 1,
         body: "Welcome to the team chat! You can @mention colleagues here.",
         sender: %{full_name: "System", initials: "SY"},
         inserted_at: DateTime.utc_now()
       },
       %{
         id: 2,
         body: "Hey @Admin, can you check the SWIFT refund ticket?",
         sender: %{full_name: "Sarah Chen", initials: "SC"},
         inserted_at: DateTime.utc_now()
       }
     ])
     |> assign(:messages, [])
     |> assign(:audit_logs, [])
     |> assign(:notifications, notifications)
     |> assign(:show_notifications, false)
     |> assign(:sidebar_collapsed, false)
     |> assign(:theme, "light")
     |> assign(:screenshot, nil)
     |> assign(
       :message_form,
       to_form(Tickets.change_ticket_message(%Helpdeskex.Tickets.TicketMessage{}))
     )
     |> assign(:show_new_ticket_modal, false)
     |> assign(:form, to_form(Tickets.change_ticket(%Helpdeskex.Tickets.Ticket{}))),
     layout: false}
  end

  @impl true
  def handle_event("switch_view", %{"view" => view}, socket) do
    {:noreply, assign(socket, :current_view, view)}
  end

  @impl true
  def handle_event("toggle_sidebar", _params, socket) do
    new_state = !socket.assigns.sidebar_collapsed

    {:noreply,
     socket
     |> assign(:sidebar_collapsed, new_state)
     |> push_event("store_state", %{key: "sidebar_collapsed", value: new_state})}
  end

  @impl true
  def handle_event("toggle_theme", _params, socket) do
    new_theme = if socket.assigns.theme == "light", do: "dark", else: "light"

    {:noreply,
     socket
     |> assign(:theme, new_theme)
     |> push_event("store_state", %{key: "theme", value: new_theme})}
  end

  @impl true
  def handle_event(
        "restore_state",
        %{"theme" => theme, "sidebar_collapsed" => sidebar_collapsed},
        socket
      ) do
    {:noreply,
     socket
     |> assign(:theme, theme)
     |> assign(:sidebar_collapsed, sidebar_collapsed)}
  end

  @impl true
  def handle_event("toggle_notifications", _params, socket) do
    {:noreply, assign(socket, :show_notifications, !socket.assigns.show_notifications)}
  end

  @impl true
  def handle_event("mark_notifications_read", _params, socket) do
    Accounts.mark_all_as_read(socket.assigns.current_user.id)
    {:noreply, assign(socket, :notifications, []) |> assign(:show_notifications, false)}
  end

  @impl true
  def handle_event("open_new_ticket", _params, socket) do
    {:noreply, assign(socket, :show_new_ticket_modal, true)}
  end

  @impl true
  def handle_event("close_new_ticket", _params, socket) do
    {:noreply, assign(socket, :show_new_ticket_modal, false) |> assign(:screenshot, nil)}
  end

  @impl true
  def handle_event("screenshot_captured", %{"image" => image}, socket) do
    {:noreply, assign(socket, :screenshot, image)}
  end

  @impl true
  def handle_event("remove_screenshot", _params, socket) do
    {:noreply, assign(socket, :screenshot, nil)}
  end

  @impl true
  def handle_event("validate_ticket", %{"ticket" => ticket_params}, socket) do
    changeset =
      %Helpdeskex.Tickets.Ticket{}
      |> Tickets.change_ticket(ticket_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :form, to_form(changeset))}
  end

  @impl true
  def handle_event("save_ticket", %{"ticket" => ticket_params}, socket) do
    # Inject current context
    params =
      ticket_params
      |> Map.put("tenant_id", socket.assigns.current_user.tenant_id)
      |> Map.put("requester_id", socket.assigns.current_user.id)
      # Add screenshot to description if it exists
      |> Map.update("description", ticket_params["description"], fn desc ->
        if socket.assigns.screenshot,
          do: (desc || "") <> "\n\n[Screenshot attached]",
          else: desc
      end)

    case Tickets.create_ticket(params) do
      {:ok, _ticket} ->
        # Refresh state
        tenant_id = socket.assigns.current_user.tenant_id
        tickets = Tickets.list_tickets(tenant_id)

        {:noreply,
         socket
         |> put_flash(:info, "Ticket created successfully")
         |> assign(:tickets, tickets)
         |> assign(:stats, compute_stats(tickets))
         |> assign(:show_new_ticket_modal, false)
         |> assign(:screenshot, nil)
         |> assign(:form, to_form(Tickets.change_ticket(%Helpdeskex.Tickets.Ticket{})))}

      {:error, changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end

  @impl true
  def handle_event("update_ticket_status", %{"id" => id, "status" => status_id}, socket) do
    ticket = Tickets.get_ticket!(id)

    case Tickets.update_ticket(ticket, %{status_id: status_id}) do
      {:ok, _ticket} ->
        # PubSub will handle the broadcast to other agents
        # Local state is updated via handle_info({:ticket_updated, ...})
        {:noreply, socket}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Could not move ticket")}
    end
  end

  @impl true
  def handle_event("save_message", %{"ticket_message" => message_params}, socket) do
    ticket = socket.assigns.selected_ticket
    user = socket.assigns.current_user

    params =
      message_params
      |> Map.put("ticket_id", ticket.id)
      |> Map.put("sender_id", user.id)

    case Tickets.create_ticket_message(params) do
      {:ok, _message} ->
        messages = Tickets.list_ticket_messages(ticket.id)

        {:noreply,
         socket
         |> assign(:messages, messages)
         |> assign(
           :message_form,
           to_form(Tickets.change_ticket_message(%Helpdeskex.Tickets.TicketMessage{}))
         )}

      {:error, changeset} ->
        {:noreply, assign(socket, :message_form, to_form(changeset))}
    end
  end

  @impl true
  def handle_event("select_ticket", %{"id" => id}, socket) do
    ticket = Enum.find(socket.assigns.tickets, fn t -> t.id == id end)
    messages = Tickets.list_ticket_messages(id)
    audit_logs = Accounts.list_audit_logs("tickets", id)

    {:noreply,
     socket
     |> assign(:selected_ticket, ticket)
     |> assign(:messages, messages)
     |> assign(:audit_logs, audit_logs)
     |> assign(
       :message_form,
       to_form(Tickets.change_ticket_message(%Helpdeskex.Tickets.TicketMessage{}))
     )}
  end

  @impl true
  def handle_event("close_panel", _params, socket) do
    {:noreply, assign(socket, :selected_ticket, nil)}
  end

  @impl true
  def handle_event("register-my-device", _, socket) do
    challenge = Helpdeskex.Accounts.PasskeyAuth.generate_challenge()
    user = socket.assigns.current_user

    {:noreply,
     push_event(socket, "register-passkey", %{
       challenge: challenge,
       user_id: user.id,
       user_email: user.email
     })}
  end

  @impl true
  def handle_event("passkey-registered", %{"id" => id, "publicKey" => pub_key}, socket) do
    user = socket.assigns.current_user

    case Helpdeskex.Accounts.PasskeyAuth.register_passkey(user, id, pub_key) do
      {:ok, _passkey} ->
        passkeys = Accounts.list_user_passkeys(user.id)

        {:noreply,
         socket
         |> assign(:passkeys, passkeys)
         |> put_flash(
           :info,
           "Passkey registered successfully! You can now log in with your phone."
         )}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to register passkey.")}
    end
  end

  @impl true
  def handle_event("delete-passkey", %{"id" => passkey_id}, socket) do
    user = socket.assigns.current_user

    case Accounts.delete_user_passkey(user.id, passkey_id) do
      {:ok, _} ->
        passkeys = Accounts.list_user_passkeys(user.id)

        {:noreply,
         socket
         |> assign(:passkeys, passkeys)
         |> put_flash(:info, "Passkey removed.")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not remove passkey.")}
    end
  end

  @impl true
  def handle_event("toggle-user-menu", _, socket) do
    # Placeholder for a user menu if needed
    {:noreply, socket}
  end

  @impl true
  def handle_info({:ticket_created, ticket}, socket) do
    # If the ticket was created by someone else, notify me
    if ticket.requester_id != socket.assigns.current_user.id do
      Accounts.create_notification(%{
        user_id: socket.assigns.current_user.id,
        title: "New Ticket Created",
        body: "#{ticket.subject}",
        type: "info"
      })
    end

    # Simply refresh the list and stats
    tenant_id = socket.assigns.current_user.tenant_id
    tickets = Tickets.list_tickets(tenant_id)

    {:noreply,
     socket
     |> assign(:tickets, tickets)
     |> assign(:stats, compute_stats(tickets))}
  end

  @impl true
  def handle_info({:ticket_updated, updated_ticket}, socket) do
    # Notify if assigned to me and updated by someone else
    if updated_ticket.assigned_to_id == socket.assigns.current_user.id do
      Accounts.create_notification(%{
        user_id: socket.assigns.current_user.id,
        title: "Ticket Updated",
        body: "Ticket ##{short_ticket_id(updated_ticket.id)} was modified.",
        type: "info"
      })

      # Dispatch Email
      UserEmail.ticket_assigned(socket.assigns.current_user, updated_ticket)
      |> Mailer.deliver()
    end

    # Update the ticket in the list
    tickets =
      Enum.map(socket.assigns.tickets, fn t ->
        if t.id == updated_ticket.id, do: updated_ticket, else: t
      end)

    # If the updated ticket is currently selected, refresh that too
    socket =
      if socket.assigns.selected_ticket && socket.assigns.selected_ticket.id == updated_ticket.id do
        assign(socket, :selected_ticket, updated_ticket)
      else
        socket
      end

    {:noreply,
     socket
     |> assign(:tickets, tickets)
     |> assign(:stats, compute_stats(tickets))}
  end

  @impl true
  def handle_info(:tick, socket) do
    # Just force a re-render to update countdowns
    {:noreply, socket}
  end

  @impl true
  def handle_info({:new_notification, notification}, socket) do
    {:noreply, assign(socket, :notifications, [notification | socket.assigns.notifications])}
  end

  defp get_first_tenant_id do
    case Helpdeskex.Repo.all(Helpdeskex.Accounts.Tenant) do
      [tenant | _] -> tenant.id
      [] -> nil
    end
  end

  defp compute_stats(tickets) do
    open_count = Enum.count(tickets, fn t -> match?(%{status: %{name: "open"}}, t) end)
    urgent_count = Enum.count(tickets, fn t -> match?(%{priority: %{name: "urgent"}}, t) end)

    in_progress_count =
      Enum.count(tickets, fn t -> match?(%{status: %{name: "in_progress"}}, t) end)

    resolved_count = Enum.count(tickets, fn t -> match?(%{status: %{name: "resolved"}}, t) end)

    %{
      open: open_count,
      urgent: urgent_count,
      in_progress: in_progress_count,
      resolved: resolved_count
    }
  end

  def tickets_by_status(tickets, status_name) do
    Enum.filter(tickets, fn t ->
      case t.status do
        %{name: ^status_name} -> true
        _ -> false
      end
    end)
  end

  def priority_class(nil), do: "priority-medium"
  def priority_class(%{name: "urgent"}), do: "priority-urgent"
  def priority_class(%{name: "high"}), do: "priority-high"
  def priority_class(%{name: "medium"}), do: "priority-medium"
  def priority_class(%{name: "low"}), do: "priority-low"

  def short_ticket_id(id) when is_binary(id) do
    "TKT-" <> String.upcase(String.slice(id, 0, 6))
  end

  def short_ticket_id(_), do: "TKT-????"

  def requester_initials(nil), do: "??"
  def requester_initials(%{full_name: nil}), do: "??"

  def requester_initials(%{full_name: name}) do
    name
    |> String.split(" ")
    |> Enum.take(2)
    |> Enum.map(&String.first/1)
    |> Enum.join()
    |> String.upcase()
  end

  def sla_countdown(ticket) do
    case ticket.status.name do
      "resolved" ->
        diff = DateTime.diff(DateTime.utc_now(), ticket.updated_at)
        "Closed #{format_duration(diff)} ago"

      "pending" ->
        "Awaiting 1d"

      _ ->
        if ticket.sla do
          diff = DateTime.diff(ticket.sla.response_by, DateTime.utc_now())

          if diff <= 0 do
            "SLA -#{format_duration(abs(diff))}"
          else
            "#{format_duration(diff)} left"
          end
        else
          nil
        end
    end
  end

  defp format_duration(diff) do
    cond do
      diff < 60 -> "#{diff}s"
      diff < 3600 -> "#{div(diff, 60)} min"
      diff < 86400 -> "#{div(diff, 3600)}h"
      true -> "#{div(diff, 86400)}d"
    end
  end

  def ticket_tags(ticket) do
    subject = String.downcase(ticket.subject)

    cond do
      String.contains?(subject, "swift") -> ["SWIFT"]
      String.contains?(subject, "refund") -> ["Refund", "Fraud"]
      String.contains?(subject, "kyc") -> ["KYC", "Compliance"]
      String.contains?(subject, "card") -> ["Cards", "Travel"]
      String.contains?(subject, "login") -> ["Mobile"]
      true -> ["Ticket"]
    end
  end

  def requester_color(nil), do: "nav-purple"

  def requester_color(requester) do
    # Simple hash-based color selection
    case rem(:erlang.phash2(requester.id), 4) do
      0 -> "nav-purple"
      1 -> "nav-teal"
      2 -> "nav-blue"
      3 -> "nav-red"
    end
  end

  def sla_status_class(nil), do: ""

  def sla_status_class(%{status: "active", response_by: response_by}) do
    diff = DateTime.diff(response_by, DateTime.utc_now())

    cond do
      diff <= 0 -> "sla-breached"
      diff < 3600 -> "sla-warning"
      true -> ""
    end
  end

  def sla_status_class(_), do: ""

  def sla_progress_percentage(nil), do: 0

  def sla_progress_percentage(%{
        status: "active",
        response_by: response_by,
        inserted_at: inserted_at
      }) do
    total = DateTime.diff(response_by, inserted_at)
    remaining = DateTime.diff(response_by, DateTime.utc_now())

    if total <= 0 or remaining <= 0 do
      100
    else
      percent = (total - remaining) / total * 100
      min(max(round(percent), 0), 100)
    end
  end

  def sla_progress_percentage(_), do: 0

  def status_color("open"), do: "#a0a0a0"
  def status_color("in_progress"), do: "#5c6bc0"
  def status_color("pending"), do: "#ffa726"
  def status_color("resolved"), do: "#66bb6a"
  def status_color(_), do: "#a0a0a0"

  def sla_color(_), do: "var(--accent-green)"

  def sla_breached?(nil), do: false

  def sla_breached?(%{status: "active", response_by: response_by}) do
    DateTime.diff(response_by, DateTime.utc_now()) <= 0
  end

  def sla_breached?(_), do: false

  def sla_warning?(nil), do: false

  def sla_warning?(%{status: "active", response_by: response_by}) do
    diff = DateTime.diff(response_by, DateTime.utc_now())
    diff > 0 and diff < 3600
  end

  def sla_warning?(_), do: false
end
