defmodule HelpdeskexWeb.ChatLive do
  use HelpdeskexWeb, :live_view

  on_mount {HelpdeskexWeb.Auth.LiveHooks, :require_authenticated_user}

  alias Helpdeskex.Chat

  @impl true
  def mount(params, _session, socket) do
    user = socket.assigns.current_user

    # Generate a short-lived Phoenix Token for the JS channel socket
    chat_token =
      Phoenix.Token.sign(HelpdeskexWeb.Endpoint, "chat_socket", user.id)

    conversations = Chat.list_conversations(user.id)

    tenant_users = Chat.list_users_for_chat(user.tenant_id, user.id)

    # Determine active conversation from URL param
    {active_conv, messages} =
      case params["conversation_id"] do
        nil ->
          {nil, []}

        id ->
          if Chat.participant?(id, user.id) do
            conv = Chat.get_conversation!(id)
            msgs = Chat.list_messages(id)

            if connected?(socket) do
              Chat.subscribe_conversation(id)
              Chat.mark_as_read(id, user.id)
            end

            {conv, msgs}
          else
            {nil, []}
          end
      end

    if connected?(socket) do
      Chat.subscribe_user(user.id)

      # Subscribe to global presence
      Phoenix.PubSub.subscribe(Helpdeskex.PubSub, "chat_presence:tenant_#{user.tenant_id}")

      Helpdeskex.Chat.Presence.track(
        self(),
        "chat_presence:tenant_#{user.tenant_id}",
        user.id,
        %{online_at: inspect(System.system_time(:second))}
      )

      # Subscribe to any already-open conversation
      if active_conv && is_nil(params["conversation_id"]) do
        Chat.subscribe_conversation(active_conv.id)
      end

      # Subscribe to typing events for the active conversation
      if params["conversation_id"] do
        Phoenix.PubSub.subscribe(Helpdeskex.PubSub, "chat_typing:#{params["conversation_id"]}")
      end
    end

    # Fetch initial presence
    presences = Helpdeskex.Chat.Presence.list("chat_presence:tenant_#{user.tenant_id}")
    online_users = Enum.reduce(Map.keys(presences), %{}, fn id, acc -> Map.put(acc, id, true) end)

    # Compute unread counts for all conversations
    unread_counts =
      conversations
      |> Enum.map(fn c -> {c.id, Chat.get_unread_count(c.id, user.id)} end)
      |> Map.new()

    {:ok,
     socket
     |> assign(:page_title, "Team Chat · HelpdeskEx")
     |> assign(:current_user, user)
     |> assign(:chat_token, chat_token)
     |> assign(:conversations, conversations)
     |> assign(:active_conversation, active_conv)
     |> assign(:tenant_users, tenant_users)
     |> assign(:unread_counts, unread_counts)
     |> assign(:show_new_chat_modal, false)
     |> assign(:show_group_modal, false)
     |> assign(:search_query, "")
     |> assign(:group_name, "")
     |> assign(:selected_members, [])
     |> assign(:typing_users, [])
     |> assign(:online_users, online_users)
     |> assign(:message_input, "")
     |> assign(:reply_to, nil)
     |> assign(:editing_message, nil)
     |> assign(:has_more_messages, length(messages) >= 50)
     |> assign(:current_scope, nil)
     |> assign(:theme, "light")
     |> assign(:sidebar_collapsed, false)
     |> assign(:show_right_sidebar, false)
     |> assign(:show_forward_modal, false)
     |> assign(:forwarding_message_id, nil)
     |> assign(:active_tab, "todos")
     |> assign(:mention_query, nil)
     |> assign(:mention_results, [])
     |> assign(:mention_index, 0)
     |> assign(:stats, %{open: 0, in_progress: 0, resolved: 0})
     |> allow_upload(:attachments,
       accept: ~w(.jpg .jpeg .png .pdf .zip .csv .doc .docx),
       max_entries: 5
     )
     |> stream(:messages, messages)
     |> stream(:todos, [])
     |> stream(:notes, [])}
  end

  @impl true
  def handle_params(%{"conversation_id" => id}, _uri, socket) do
    user = socket.assigns.current_user

    if Chat.participant?(id, user.id) do
      conv = Chat.get_conversation!(id)
      messages = Chat.list_messages(id)

      if connected?(socket) do
        Chat.subscribe_conversation(id)
        Chat.mark_as_read(id, user.id)
      end

      unread_counts = Map.put(socket.assigns.unread_counts, id, 0)

      {:noreply,
       socket
       |> assign(:active_conversation, conv)
       |> assign(:unread_counts, unread_counts)
       |> assign(:reply_to, nil)
       |> assign(:editing_message, nil)
       |> assign(:has_more_messages, length(messages) >= 50)
       |> stream(:messages, messages, reset: true)}
    else
      {:noreply,
       socket |> put_flash(:error, "Conversation not found.") |> push_patch(to: "/chat")}
    end
  end

  def handle_params(_params, _uri, socket) do
    {:noreply, socket}
  end

  # ── Events ────────────────────────────────────────────────────────────────

  @impl true
  def handle_event("send_message", %{"body" => body}, socket) do
    body = String.trim(body)

    # Consume uploads
    uploaded_files =
      consume_uploaded_entries(socket, :attachments, fn %{path: path}, entry ->
        uploads_dir = Path.join([:code.priv_dir(:helpdeskex), "static", "uploads", "chat"])
        File.mkdir_p!(uploads_dir)

        filename = "#{entry.uuid}-#{String.replace(entry.client_name, " ", "_")}"
        dest = Path.join(uploads_dir, filename)

        File.cp!(path, dest)

        {:ok,
         %{url: "/uploads/chat/#{filename}", name: entry.client_name, type: entry.client_type}}
      end)

    if body != "" or not Enum.empty?(uploaded_files) do
      conv = socket.assigns.active_conversation
      user = socket.assigns.current_user

      reply_to_id = socket.assigns.reply_to && socket.assigns.reply_to.id

      # Determine message type and metadata
      {type, metadata} =
        if not Enum.empty?(uploaded_files) do
          {"file", Jason.encode!(%{"attachments" => uploaded_files})}
        else
          {"text", nil}
        end

      attrs = %{
        "body" => body,
        "type" => type,
        "metadata" => metadata,
        "reply_to_id" => reply_to_id
      }

      Chat.send_message(conv.id, user.id, attrs)
    end

    {:noreply, socket |> assign(:reply_to, nil) |> assign(:message_input, "")}
  end

  def handle_event("edit_last_message", _params, socket) do
    user = socket.assigns.current_user
    conv = socket.assigns.active_conversation

    # Simple logic to find last message by this user
    last_msg =
      Chat.list_messages(conv.id)
      |> Enum.filter(&(&1.sender_id == user.id))
      |> List.first()

    if last_msg do
      {:noreply, assign(socket, :editing_message, last_msg)}
    else
      {:noreply, socket}
    end
  end

  def handle_event("typing_start", _params, socket) do
    user = socket.assigns.current_user
    conv = socket.assigns.active_conversation

    if conv do
      Phoenix.PubSub.broadcast(
        Helpdeskex.PubSub,
        "chat_typing:#{conv.id}",
        {:user_typing, user.id, user.full_name}
      )
    end

    {:noreply, socket}
  end

  def handle_event("typing_stop", _params, socket) do
    user = socket.assigns.current_user
    conv = socket.assigns.active_conversation

    if conv do
      Phoenix.PubSub.broadcast(
        Helpdeskex.PubSub,
        "chat_typing:#{conv.id}",
        {:user_stopped_typing, user.id}
      )
    end

    {:noreply, socket}
  end

  def handle_event("validate_upload", %{"body" => body} = params, socket) do
    # Only update message_input if it's the main form
    socket =
      if params["_target"] == ["body"] or params["_target"] == ["attachments"] do
        handle_mentions(body, socket)
        |> assign(:message_input, body)
      else
        socket
      end

    {:noreply, socket}
  end

  def handle_event("validate_upload", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("toggle_right_sidebar", _params, socket) do
    new_state = !socket.assigns.show_right_sidebar
    socket = if new_state, do: load_productivity_data(socket), else: socket
    {:noreply, assign(socket, :show_right_sidebar, new_state)}
  end

  def handle_event("set_active_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, :active_tab, tab)}
  end

  def handle_event("select_mention", %{"user_id" => user_id}, socket) do
    user = Enum.find(socket.assigns.tenant_users, &(&1.id == user_id))
    current_body = socket.assigns.message_input

    # Replace the @query with the full name
    new_body = String.replace(current_body, ~r/@[^\s]*$/, "@#{user.full_name} ")

    {:noreply,
     socket
     |> assign(:message_input, new_body)
     |> assign(:mention_query, nil)
     |> assign(:mention_results, [])}
  end

  def handle_event("cancel_upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :attachments, ref)}
  end

  def handle_event("toggle_todo_status", %{"id" => id}, socket) do
    todo = Helpdeskex.Repo.get!(Chat.Todo, id)

    case Chat.update_todo(todo, %{is_completed: !todo.is_completed}) do
      {:ok, todo} ->
        {:noreply, stream_insert(socket, :todos, todo)}

      _ ->
        {:noreply, socket}
    end
  end

  def handle_event("open_personal_space", _params, socket) do
    user = socket.assigns.current_user

    case Chat.get_or_create_direct_conversation(user.id, user.id, user.tenant_id) do
      {:ok, conv} ->
        {:noreply, push_patch(socket, to: "/chat/#{conv.id}")}

      _ ->
        {:noreply, socket}
    end
  end

  def handle_event("open_forward_modal", %{"message_id" => msg_id}, socket) do
    {:noreply,
     socket |> assign(:show_forward_modal, true) |> assign(:forwarding_message_id, msg_id)}
  end

  def handle_event("close_forward_modal", _params, socket) do
    {:noreply,
     socket |> assign(:show_forward_modal, false) |> assign(:forwarding_message_id, nil)}
  end

  def handle_event("forward_message", %{"to_conversation_id" => conv_id}, socket) do
    user = socket.assigns.current_user
    msg = Chat.get_message!(socket.assigns.forwarding_message_id)

    attrs = %{
      body: "[Forwarded] #{msg.body}",
      metadata: %{forwarded_from: msg.id}
    }

    case Chat.send_message(conv_id, user.id, attrs) do
      {:ok, _} ->
        {:noreply,
         socket
         |> assign(:show_forward_modal, false)
         |> put_flash(:info, "Message forwarded")}

      _ ->
        {:noreply, socket |> put_flash(:error, "Could not forward message")}
    end
  end

  def handle_event("toggle_reactions", %{"message_id" => _msg_id}, socket) do
    # Simple placeholder for reactions picker logic
    {:noreply, socket}
  end

  def handle_event("add_todo", _params, socket) do
    user = socket.assigns.current_user
    conv = socket.assigns.active_conversation

    # In a real app we'd show an input first, here we'll create a default one to show it works
    attrs = %{
      "conversation_id" => conv.id,
      "created_by_id" => user.id,
      "title" => "New Task",
      "is_completed" => false
    }

    case Chat.create_todo(attrs) do
      {:ok, todo} ->
        {:noreply, stream_insert(socket, :todos, todo, at: 0)}

      _ ->
        {:noreply, socket}
    end
  end

  def handle_event("add_note", _params, socket) do
    user = socket.assigns.current_user
    conv = socket.assigns.active_conversation

    attrs = %{
      "conversation_id" => conv.id,
      "created_by_id" => user.id,
      "body" => "Shared note started...",
      "attachments" => %{}
    }

    case Chat.create_note(attrs) do
      {:ok, note} ->
        {:noreply, stream_insert(socket, :notes, note, at: 0)}

      _ ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("set_reply_to", %{"message_id" => msg_id}, socket) do
    message = Chat.get_message!(msg_id)
    {:noreply, assign(socket, :reply_to, message)}
  end

  @impl true
  def handle_event("cancel_reply", _params, socket) do
    {:noreply, assign(socket, :reply_to, nil)}
  end

  @impl true
  def handle_event("start_edit", %{"message_id" => msg_id}, socket) do
    message = Chat.get_message!(msg_id)
    {:noreply, assign(socket, :editing_message, message)}
  end

  @impl true
  def handle_event("cancel_edit", _params, socket) do
    {:noreply, assign(socket, :editing_message, nil)}
  end

  @impl true
  def handle_event("save_edit", %{"body" => new_body}, socket) do
    user = socket.assigns.current_user
    message = socket.assigns.editing_message

    case Chat.edit_message(message, user.id, new_body) do
      {:ok, _updated} ->
        {:noreply, assign(socket, :editing_message, nil)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not edit message")}
    end
  end

  @impl true
  def handle_event("delete_message", %{"message_id" => msg_id}, socket) do
    user = socket.assigns.current_user
    message = Chat.get_message!(msg_id)

    case Chat.delete_message(message, user.id) do
      {:ok, _} -> {:noreply, socket}
      {:error, :unauthorized} -> {:noreply, put_flash(socket, :error, "Not authorized")}
      {:error, _} -> {:noreply, put_flash(socket, :error, "Could not delete message")}
    end
  end

  @impl true
  def handle_event("open_new_chat", _params, socket) do
    {:noreply, assign(socket, :show_new_chat_modal, true)}
  end

  @impl true
  def handle_event("close_new_chat", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_new_chat_modal, false)
     |> assign(:search_query, "")}
  end

  @impl true
  def handle_event("open_group_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_group_modal, true)
     |> assign(:selected_members, [socket.assigns.current_user.id])}
  end

  @impl true
  def handle_event("close_group_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_group_modal, false)
     |> assign(:group_name, "")
     |> assign(:selected_members, [])}
  end

  @impl true
  def handle_event("search_users", %{"value" => q}, socket) do
    {:noreply, assign(socket, :search_query, String.downcase(q))}
  end

  @impl true
  def handle_event("set_group_name", %{"value" => name}, socket) do
    {:noreply, assign(socket, :group_name, name)}
  end

  @impl true
  def handle_event("toggle_member", %{"user_id" => uid}, socket) do
    current = socket.assigns.selected_members

    members =
      if uid in current do
        List.delete(current, uid)
      else
        [uid | current]
      end

    {:noreply, assign(socket, :selected_members, members)}
  end

  @impl true
  def handle_event("start_direct_chat", %{"user_id" => other_user_id}, socket) do
    user = socket.assigns.current_user

    case Chat.get_or_create_direct_conversation(user.id, other_user_id, user.tenant_id) do
      {:ok, conv} ->
        conversations = Chat.list_conversations(user.id)

        {:noreply,
         socket
         |> assign(:show_new_chat_modal, false)
         |> assign(:search_query, "")
         |> assign(:conversations, conversations)
         |> push_patch(to: "/chat/#{conv.id}")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not open conversation")}
    end
  end

  @impl true
  def handle_event("create_group", _params, socket) do
    user = socket.assigns.current_user
    group_name = String.trim(socket.assigns.group_name)
    members = socket.assigns.selected_members

    if group_name == "" do
      {:noreply, put_flash(socket, :error, "Please enter a group name")}
    else
      all_members = Enum.uniq([user.id | members])

      attrs = %{
        "name" => group_name,
        "type" => "group",
        "tenant_id" => user.tenant_id,
        "created_by_id" => user.id
      }

      case Chat.create_group_conversation(attrs, all_members) do
        {:ok, conv} ->
          conversations = Chat.list_conversations(user.id)

          {:noreply,
           socket
           |> assign(:show_group_modal, false)
           |> assign(:group_name, "")
           |> assign(:selected_members, [])
           |> assign(:conversations, conversations)
           |> push_patch(to: "/chat/#{conv.id}")}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Could not create group")}
      end
    end
  end

  @impl true
  def handle_event("load_more_messages", _params, socket) do
    conv = socket.assigns.active_conversation

    # Find the oldest message currently in view
    oldest_id =
      case socket.assigns.streams.messages.inserts do
        [] -> nil
        items -> items |> List.last() |> elem(1) |> Map.get(:id)
      end

    messages = Chat.list_messages(conv.id, before_id: oldest_id)
    has_more = length(messages) >= 50

    {:noreply,
     socket
     |> assign(:has_more_messages, has_more)
     |> stream(:messages, messages, at: 0)}
  end

  @impl true
  def handle_event("toggle_sidebar", _params, socket) do
    {:noreply, assign(socket, :sidebar_collapsed, !socket.assigns.sidebar_collapsed)}
  end

  @impl true
  def handle_event("restore_state", %{"theme" => theme, "sidebar_collapsed" => sc}, socket) do
    {:noreply, socket |> assign(:theme, theme) |> assign(:sidebar_collapsed, sc)}
  end

  @impl true
  def handle_event("switch_view", %{"view" => _view}, socket) do
    {:noreply, socket}
  end

  # ── PubSub handlers ───────────────────────────────────────────────────────

  @impl true
  def handle_info({:user_typing, user_id, full_name}, socket) do
    if user_id != socket.assigns.current_user.id do
      typing =
        [%{id: user_id, name: full_name} | socket.assigns.typing_users] |> Enum.uniq_by(& &1.id)

      {:noreply, assign(socket, :typing_users, typing)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:user_stopped_typing, user_id}, socket) do
    typing = Enum.reject(socket.assigns.typing_users, &(&1.id == user_id))
    {:noreply, assign(socket, :typing_users, typing)}
  end

  @impl true
  def handle_info({:new_message, message}, socket) do
    conv_id = message.conversation_id
    user = socket.assigns.current_user

    # Update unread count if not the active conversation
    socket =
      if socket.assigns.active_conversation &&
           socket.assigns.active_conversation.id == conv_id do
        # We're looking at this conversation — mark as read
        Chat.mark_as_read(conv_id, user.id)
        socket |> stream_insert(:messages, message)
      else
        unread = Map.get(socket.assigns.unread_counts, conv_id, 0)
        assign(socket, :unread_counts, Map.put(socket.assigns.unread_counts, conv_id, unread + 1))
      end

    # Update conversation list to show latest message preview
    conversations = Chat.list_conversations(user.id)
    {:noreply, assign(socket, :conversations, conversations)}
  end

  @impl true
  def handle_info({:message_updated, message}, socket) do
    {:noreply, stream_insert(socket, :messages, message)}
  end

  @impl true
  def handle_info({:message_deleted, message}, socket) do
    {:noreply, stream_insert(socket, :messages, message)}
  end

  @impl true
  def handle_info(%Phoenix.Socket.Broadcast{event: "presence_diff"}, socket) do
    user = socket.assigns.current_user
    presences = Helpdeskex.Chat.Presence.list("chat_presence:tenant_#{user.tenant_id}")
    online_users = Enum.reduce(Map.keys(presences), %{}, fn id, acc -> Map.put(acc, id, true) end)
    {:noreply, assign(socket, :online_users, online_users)}
  end

  @impl true
  def handle_info({:messages_read, %{user_id: _uid, conversation_id: _conv_id}}, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_info({:new_conversation, conv}, socket) do
    user = socket.assigns.current_user
    conversations = Chat.list_conversations(user.id)

    # Subscribe to new conversation's PubSub
    Chat.subscribe_conversation(conv.id)

    {:noreply,
     socket
     |> assign(:conversations, conversations)
     |> assign(:unread_counts, Map.put(socket.assigns.unread_counts, conv.id, 0))}
  end

  # ── Helpers ───────────────────────────────────────────────────────────────

  def conversation_name(%{type: "direct"} = conv, current_user) do
    other =
      conv.participants
      |> Enum.find(fn p -> p.user_id != current_user.id end)

    case other do
      nil -> "Direct Message"
      %{user: user} -> user.full_name || user.email
    end
  end

  def conversation_name(%{name: name}, _current_user) when is_binary(name), do: name
  def conversation_name(_, _), do: "Group Chat"

  def conversation_avatar(%{type: "direct"} = conv, current_user) do
    other =
      conv.participants
      |> Enum.find(fn p -> p.user_id != current_user.id end)

    case other do
      nil -> "??"
      %{user: user} -> user_initials(user.full_name)
    end
  end

  def conversation_avatar(%{name: name}, _) when is_binary(name) do
    name |> String.first() |> String.upcase()
  end

  def conversation_avatar(_, _), do: "G"

  def last_message_preview([]), do: "No messages yet"

  def last_message_preview(messages) do
    msg = List.last(messages)

    cond do
      msg.deleted_at -> "🚫 Message deleted"
      msg.type == "image" -> "📷 Image"
      msg.type == "file" -> "📎 File"
      true -> String.slice(msg.body || "", 0, 60)
    end
  end

  def user_initials(nil), do: "??"

  def user_initials(name) do
    name
    |> String.split(" ")
    |> Enum.take(2)
    |> Enum.map(&String.first/1)
    |> Enum.join()
    |> String.upcase()
  end

  def format_message_time(%{inserted_at: dt}) do
    now = DateTime.utc_now()
    diff = DateTime.diff(now, dt, :second)

    cond do
      diff < 60 -> "just now"
      diff < 3600 -> "#{div(diff, 60)}m ago"
      diff < 86_400 -> Calendar.strftime(dt, "%H:%M")
      true -> Calendar.strftime(dt, "%d %b")
    end
  end

  def format_last_seen(nil), do: "Offline"

  def format_last_seen(%DateTime{} = dt) do
    now = DateTime.utc_now()
    diff = DateTime.diff(now, dt, :minute)

    cond do
      diff < 2 -> "Active just now"
      diff < 60 -> "Last seen #{diff}m ago"
      diff < 1440 -> "Last seen #{div(diff, 60)}h ago"
      true -> "Last seen #{Calendar.strftime(dt, "%b %d")}"
    end
  end

  def format_last_seen(_), do: "Offline"

  def decode_attachments(nil), do: []

  def decode_attachments(metadata) when is_binary(metadata) do
    case Jason.decode(metadata) do
      {:ok, %{"attachments" => attachments}} when is_list(attachments) -> attachments
      _ -> []
    end
  end

  def decode_attachments(_), do: []

  def avatar_color(id) when is_binary(id) do
    colors = ["chat-av-purple", "chat-av-teal", "chat-av-blue", "chat-av-green", "chat-av-orange"]
    Enum.at(colors, rem(:erlang.phash2(id), length(colors)))
  end

  def avatar_color(_), do: "chat-av-purple"

  def filtered_users(users, query) when query == "", do: users

  def filtered_users(users, query) do
    Enum.filter(users, fn u ->
      name = String.downcase(u.full_name || "")
      email = String.downcase(u.email || "")
      String.contains?(name, query) or String.contains?(email, query)
    end)
  end

  defp handle_mentions(body, socket) do
    case Regex.run(~r/@[^\s]*$/, body) do
      [mention] ->
        query = String.slice(mention, 1..-1//1)

        results =
          socket.assigns.tenant_users
          |> Enum.filter(fn u ->
            String.contains?(String.downcase(u.full_name), String.downcase(query))
          end)
          |> Enum.take(5)

        socket
        |> assign(:mention_query, query)
        |> assign(:mention_results, results)
        |> assign(:mention_index, 0)

      _ ->
        socket
        |> assign(:mention_query, nil)
        |> assign(:mention_results, [])
    end
  end

  defp load_productivity_data(socket) do
    conv = socket.assigns.active_conversation

    if conv do
      todos = Chat.list_todos(conv.id)
      notes = Chat.list_notes(conv.id)

      socket
      |> stream(:todos, todos, reset: true)
      |> stream(:notes, notes, reset: true)
    else
      socket
    end
  end
end
