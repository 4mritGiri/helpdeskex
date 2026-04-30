defmodule HelpdeskexWeb.Auth.LiveHooks do
  @moduledoc """
  LiveView on_mount hooks for authentication.
  """

  import Phoenix.LiveView
  import Phoenix.Component

  alias Helpdeskex.Accounts.Guardian

  def on_mount(:require_authenticated_user, _params, session, socket) do
    socket = mount_current_user(socket, session)

    if socket.assigns.current_user do
      {:cont, socket}
    else
      socket =
        socket
        |> put_flash(:error, "You must be logged in to access this page.")
        |> redirect(to: "/login")

      {:halt, socket}
    end
  end

  def on_mount(:mount_current_user, _params, session, socket) do
    {:cont, mount_current_user(socket, session)}
  end

  defp mount_current_user(socket, session) do
    # Guardian stores the token in the session under "guardian_default_token"
    case Guardian.resource_from_token(session["guardian_default_token"]) do
      {:ok, user, _claims} ->
        assign(socket, :current_user, user)

      _ ->
        assign(socket, :current_user, nil)
    end
  end
end
