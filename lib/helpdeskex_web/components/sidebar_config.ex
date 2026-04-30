defmodule HelpdeskexWeb.SidebarConfig do
  @moduledoc """
  Configuration for the application sidebar.
  """

  def sidebar_items(user) do
    [
      %{
        id: "kanban",
        label: "Kanban board",
        icon: "hero-squares-2x2",
        view: "kanban",
        # Publicly accessible for now
        permission: nil
      },
      %{
        id: "chat",
        label: "Team Chat",
        icon: "hero-chat-bubble-left-right",
        view: "chat",
        badge: nil,
        permission: nil
      },
      %{
        id: "all_tickets",
        label: "All tickets",
        icon: "hero-list-bullet",
        view: "all_tickets",
        badge_count: true,
        permission: nil
      },
      %{
        section: "Channels"
      },
      %{
        id: "chat_general",
        label: "General",
        icon: "hero-hashtag",
        view: "chat",
        permission: nil
      },
      %{
        id: "chat_urgent",
        label: "Urgent items",
        icon: "hero-bolt",
        view: "chat",
        badge: "3",
        permission: nil
      },
      %{
        section: "Manage"
      },
      %{
        id: "reports",
        label: "Reports",
        icon: "hero-chart-bar",
        view: "reports",
        # Example permission
        permission: :admin
      },
      %{
        id: "settings",
        label: "Settings",
        icon: "hero-cog-6-tooth",
        view: "settings",
        permission: :admin
      }
    ]
    |> Enum.filter(&has_permission?(user, &1))
  end

  defp has_permission?(_user, %{permission: nil}), do: true

  defp has_permission?(_user, %{permission: :admin}) do
    # Assuming user has a role field. Adjust based on actual schema.
    # For now, let's look at the agent-role in HTML which says "System Admin"
    # In a real app, this would be user.role == "admin"
    # Default to true for now to show all
    true
  end

  defp has_permission?(_user, _), do: true
end
