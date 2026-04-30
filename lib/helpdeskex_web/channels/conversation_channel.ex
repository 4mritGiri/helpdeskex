defmodule HelpdeskexWeb.ConversationChannel do
  @moduledoc """
  Real-time channel for a single conversation.

  Clients join topic "conversation:{conversation_id}".
  Handles messaging, typing indicators, and read receipts.
  """
  use HelpdeskexWeb, :channel

  alias Helpdeskex.Chat
  alias Helpdeskex.Chat.Presence

  @impl true
  def join("conversation:" <> conversation_id, _payload, socket) do
    user_id = socket.assigns.user_id

    if Chat.participant?(conversation_id, user_id) do
      send(self(), {:after_join, conversation_id})

      {:ok,
       socket
       |> assign(:conversation_id, conversation_id)
       |> assign(:user_id, user_id)}
    else
      {:error, %{reason: "unauthorized"}}
    end
  end

  @impl true
  def handle_info({:after_join, conversation_id}, socket) do
    user_id = socket.assigns.user_id

    # Track presence
    {:ok, _} =
      Presence.track(socket, user_id, %{
        online_at: DateTime.utc_now() |> DateTime.to_unix(),
        typing: false
      })

    # Push current presence state
    push(socket, "presence_state", Presence.list(socket))

    # Push recent message history
    messages = Chat.list_messages(conversation_id)
    push(socket, "history", %{messages: format_messages(messages)})

    # Mark conversation as read on join
    Chat.mark_as_read(conversation_id, user_id)

    {:noreply, socket}
  end

  # ── Incoming events ──────────────────────────────────────────────────────

  @impl true
  def handle_in("new_message", %{"body" => body} = payload, socket) do
    conversation_id = socket.assigns.conversation_id
    user_id = socket.assigns.user_id

    attrs = %{
      "body" => body,
      "type" => Map.get(payload, "type", "text"),
      "reply_to_id" => Map.get(payload, "reply_to_id")
    }

    case Chat.send_message(conversation_id, user_id, attrs) do
      {:ok, message} ->
        {:reply, {:ok, %{message: format_message(message)}}, socket}

      {:error, _changeset} ->
        {:reply, {:error, %{reason: "could not send message"}}, socket}
    end
  end

  @impl true
  def handle_in("typing", %{"typing" => typing}, socket) do
    user_id = socket.assigns.user_id

    Presence.update(socket, user_id, fn meta ->
      Map.put(meta, :typing, typing)
    end)

    {:noreply, socket}
  end

  @impl true
  def handle_in("read", _payload, socket) do
    conversation_id = socket.assigns.conversation_id
    user_id = socket.assigns.user_id

    Chat.mark_as_read(conversation_id, user_id)
    {:noreply, socket}
  end

  @impl true
  def handle_in("edit_message", %{"message_id" => msg_id, "body" => new_body}, socket) do
    user_id = socket.assigns.user_id

    message = Chat.get_message!(msg_id)

    case Chat.edit_message(message, user_id, new_body) do
      {:ok, updated} ->
        {:reply, {:ok, %{message: format_message(updated)}}, socket}

      {:error, :unauthorized} ->
        {:reply, {:error, %{reason: "unauthorized"}}, socket}

      {:error, _changeset} ->
        {:reply, {:error, %{reason: "could not edit message"}}, socket}
    end
  end

  @impl true
  def handle_in("delete_message", %{"message_id" => msg_id}, socket) do
    user_id = socket.assigns.user_id
    message = Chat.get_message!(msg_id)

    case Chat.delete_message(message, user_id) do
      {:ok, _deleted} ->
        {:reply, {:ok, %{message_id: msg_id}}, socket}

      {:error, :unauthorized} ->
        {:reply, {:error, %{reason: "unauthorized"}}, socket}

      {:error, _} ->
        {:reply, {:error, %{reason: "could not delete message"}}, socket}
    end
  end

  @impl true
  def handle_in("load_more", %{"before_id" => before_id}, socket) do
    messages = Chat.list_messages(socket.assigns.conversation_id, before_id: before_id)
    {:reply, {:ok, %{messages: format_messages(messages)}}, socket}
  end

  # ── Private helpers ──────────────────────────────────────────────────────

  defp format_messages(messages), do: Enum.map(messages, &format_message/1)

  defp format_message(msg) do
    %{
      id: msg.id,
      body: if(msg.deleted_at, do: nil, else: msg.body),
      type: msg.type,
      deleted: !is_nil(msg.deleted_at),
      edited: !is_nil(msg.edited_at),
      sender: format_user(msg.sender),
      reply_to: msg.reply_to && format_message(msg.reply_to),
      attachments: Enum.map(msg.attachments || [], &format_attachment/1),
      inserted_at: DateTime.to_unix(msg.inserted_at)
    }
  end

  defp format_user(nil), do: nil

  defp format_user(user) do
    %{
      id: user.id,
      full_name: user.full_name,
      email: user.email,
      initials: initials(user.full_name)
    }
  end

  defp format_attachment(att) do
    %{
      id: att.id,
      filename: att.filename,
      content_type: att.content_type,
      size: att.size,
      path: att.path
    }
  end

  defp initials(nil), do: "??"

  defp initials(name) do
    name
    |> String.split(" ")
    |> Enum.take(2)
    |> Enum.map(&String.first/1)
    |> Enum.join()
    |> String.upcase()
  end
end
