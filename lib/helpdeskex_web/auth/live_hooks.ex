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
      if connected?(socket) do
        Helpdeskex.Chat.subscribe_user(socket.assigns.current_user.id)
      end

      socket =
        attach_hook(socket, :chat_notifications, :handle_info, fn
          {:new_message_notification, msg}, socket ->
            active_id =
              Map.get(socket.assigns, :active_conversation) &&
                socket.assigns.active_conversation.id

            if active_id != msg.conversation_id do
              {:halt,
               put_flash(
                 socket,
                 :info,
                 "Chat: #{msg.sender.full_name}: #{String.slice(msg.body || "Sent an attachment", 0, 30)}"
               )}
            else
              {:halt, socket}
            end

          _, socket ->
            {:cont, socket}
        end)

      {:cont, socket}
    else
      socket =
        socket
        |> put_flash(:error, "You must be logged in to access this page.")
        |> redirect(to: "/login")

      {:halt, socket}
    end
  end

  def on_mount(:redirect_if_user_is_authenticated, _params, session, socket) do
    socket = mount_current_user(socket, session)

    if socket.assigns.current_user do
      {:halt, redirect(socket, to: "/")}
    else
      {:cont, socket}
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
