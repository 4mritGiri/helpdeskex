defmodule Helpdeskex.Chat do
  @moduledoc """
  The Chat context.

  Manages conversations, participants, messages, and presence tracking
  for the real-time team chat system.
  """

  import Ecto.Query, warn: false
  alias Helpdeskex.Repo

  alias Helpdeskex.Chat.Conversation
  alias Helpdeskex.Chat.Participant
  alias Helpdeskex.Chat.Message
  alias Helpdeskex.Chat.Todo
  alias Helpdeskex.Chat.Note
  alias Helpdeskex.Chat.Attachment
  alias Helpdeskex.Chat.MessageReaction
  alias Helpdeskex.Chat.MessageStatus
  alias Helpdeskex.Accounts.User

  # ──────────────────────────────────────────────────────────────────────────
  # PubSub helpers
  # ──────────────────────────────────────────────────────────────────────────

  @doc "Subscribe to all events for a specific conversation."
  def subscribe_conversation(conversation_id) do
    Phoenix.PubSub.subscribe(Helpdeskex.PubSub, "chat:conversation:#{conversation_id}")
  end

  @doc "Subscribe to personal events for a user (new conversations, notifications)."
  def subscribe_user(user_id) do
    Phoenix.PubSub.subscribe(Helpdeskex.PubSub, "chat:user:#{user_id}")
  end

  defp broadcast_conversation(conversation_id, event) do
    Phoenix.PubSub.broadcast(
      Helpdeskex.PubSub,
      "chat:conversation:#{conversation_id}",
      event
    )
  end

  defp broadcast_user(user_id, event) do
    Phoenix.PubSub.broadcast(Helpdeskex.PubSub, "chat:user:#{user_id}", event)
  end

  # ──────────────────────────────────────────────────────────────────────────
  # Conversations
  # ──────────────────────────────────────────────────────────────────────────

  @doc "List all conversations for a user, ordered by last message time."
  def list_conversations(user_id) do
    last_msg_subquery =
      from m in Message,
        group_by: m.conversation_id,
        select: %{conversation_id: m.conversation_id, last_msg_at: max(m.inserted_at)}

    Repo.all(
      from c in Conversation,
        join: p in Participant,
        on: p.conversation_id == c.id and p.user_id == ^user_id,
        left_join: last_msg in subquery(last_msg_subquery),
        on: last_msg.conversation_id == c.id,
        order_by: [desc: coalesce(last_msg.last_msg_at, c.inserted_at)],
        preload: [
          participants: [user: []],
          messages:
            ^from(m in Message, order_by: [desc: m.inserted_at], limit: 1, preload: [:sender])
        ]
    )
  end

  @doc "Get a conversation with full preloads."
  def get_conversation!(id) do
    Repo.get!(Conversation, id)
    |> Repo.preload(participants: [user: []], messages: [])
  end

  @doc "Get a conversation by id, returning nil if not found."
  def get_conversation(id) do
    Repo.get(Conversation, id)
    |> case do
      nil -> nil
      conv -> Repo.preload(conv, participants: [user: []])
    end
  end

  @doc """
  Find or create a direct conversation between two users.
  Returns {:ok, conversation} or {:error, changeset}.
  """
  def get_or_create_direct_conversation(user_id, other_user_id, tenant_id) do
    # Look for an existing direct conversation with exactly these two participants
    existing =
      Repo.one(
        from c in Conversation,
          join: p1 in Participant,
          on: p1.conversation_id == c.id and p1.user_id == ^user_id,
          join: p2 in Participant,
          on: p2.conversation_id == c.id and p2.user_id == ^other_user_id,
          where: c.type == "direct" and c.tenant_id == ^tenant_id,
          limit: 1
      )

    case existing do
      nil -> create_direct_conversation(user_id, other_user_id, tenant_id)
      conv -> {:ok, Repo.preload(conv, participants: [user: []])}
    end
  end

  defp create_direct_conversation(user_id, other_user_id, tenant_id) do
    Repo.transaction(fn ->
      {:ok, conv} =
        %Conversation{}
        |> Conversation.changeset(%{
          type: "direct",
          tenant_id: tenant_id,
          created_by_id: user_id
        })
        |> Repo.insert()

      {:ok, _} =
        %Participant{}
        |> Participant.changeset(%{conversation_id: conv.id, user_id: user_id, role: "admin"})
        |> Repo.insert()

      if user_id != other_user_id do
        {:ok, _} =
          %Participant{}
          |> Participant.changeset(%{
            conversation_id: conv.id,
            user_id: other_user_id,
            role: "member"
          })
          |> Repo.insert()

        conv = Repo.preload(conv, participants: [user: []])
        # Notify the other user
        broadcast_user(other_user_id, {:new_conversation, conv})
        conv
      else
        Repo.preload(conv, participants: [user: []])
      end
    end)
  end

  @doc "Create a named group conversation with the given user_ids."
  def create_group_conversation(attrs, user_ids) do
    Repo.transaction(fn ->
      {:ok, conv} =
        %Conversation{}
        |> Conversation.changeset(attrs)
        |> Repo.insert()

      for user_id <- user_ids do
        role =
          if user_id == attrs[:created_by_id] || user_id == attrs["created_by_id"],
            do: "admin",
            else: "member"

        %Participant{}
        |> Participant.changeset(%{conversation_id: conv.id, user_id: user_id, role: role})
        |> Repo.insert!()
      end

      conv = Repo.preload(conv, participants: [user: []])

      for user_id <- user_ids do
        broadcast_user(user_id, {:new_conversation, conv})
      end

      conv
    end)
  end

  @doc "Check whether a user is a participant in a conversation."
  def participant?(conversation_id, user_id) do
    Repo.exists?(
      from p in Participant,
        where: p.conversation_id == ^conversation_id and p.user_id == ^user_id
    )
  end

  @doc "Rename a group conversation."
  def rename_conversation(%Conversation{} = conv, name) do
    conv
    |> Conversation.changeset(%{name: name})
    |> Repo.update()
  end

  # ──────────────────────────────────────────────────────────────────────────
  # Messages
  # ──────────────────────────────────────────────────────────────────────────

  @messages_per_page 50

  @doc "List messages for a conversation (newest first), with optional cursor for pagination."
  def list_messages(conversation_id, opts \\ []) do
    before_id = Keyword.get(opts, :before_id)
    limit = Keyword.get(opts, :limit, @messages_per_page)

    query =
      from m in Message,
        where: m.conversation_id == ^conversation_id and is_nil(m.deleted_at),
        order_by: [desc: m.inserted_at],
        limit: ^limit,
        preload: [:sender, :attachments, :reactions, :statuses, reply_to: [:sender]]

    query =
      if before_id do
        cursor_msg = Repo.get!(Message, before_id)

        from m in query,
          where: m.inserted_at < ^cursor_msg.inserted_at
      else
        query
      end

    Repo.all(query) |> Enum.reverse()
  end

  @doc "Send a text/media message to a conversation and broadcast to subscribers."
  def send_message(conversation_id, sender_id, attrs) do
    params =
      attrs
      |> Map.put("conversation_id", conversation_id)
      |> Map.put("sender_id", sender_id)

    result =
      %Message{}
      |> Message.changeset(params)
      |> Repo.insert()

    case result do
      {:ok, message} ->
        message =
          Repo.preload(message, [
            :sender,
            :attachments,
            :reactions,
            :statuses,
            reply_to: [:sender]
          ])

        broadcast_conversation(conversation_id, {:new_message, message})

        participants =
          Repo.all(from p in Participant, where: p.conversation_id == ^conversation_id)

        for p <- participants, p.user_id != sender_id do
          broadcast_user(p.user_id, {:new_message_notification, message})
        end

        {:ok, message}

      {:error, changeset} ->
        IO.inspect(changeset.errors, label: "Message Sending Failed!")
        {:error, changeset}
    end
  end

  @doc "Soft-delete a message (only the sender can do this)."
  def delete_message(%Message{} = message, user_id) do
    if message.sender_id == user_id do
      message
      |> Message.changeset(%{deleted_at: DateTime.utc_now() |> DateTime.truncate(:second)})
      |> Repo.update()
      |> case do
        {:ok, updated} ->
          broadcast_conversation(message.conversation_id, {:message_deleted, updated})
          {:ok, updated}

        error ->
          error
      end
    else
      {:error, :unauthorized}
    end
  end

  @doc "Edit a message body."
  def edit_message(%Message{} = message, user_id, new_body) do
    if message.sender_id == user_id do
      message
      |> Message.changeset(%{
        body: new_body,
        edited_at: DateTime.utc_now() |> DateTime.truncate(:second)
      })
      |> Repo.update()
      |> case do
        {:ok, updated} ->
          updated = Repo.preload(updated, [:sender, :attachments, :statuses, reply_to: [:sender]])
          broadcast_conversation(message.conversation_id, {:message_updated, updated})
          {:ok, updated}

        error ->
          error
      end
    else
      {:error, :unauthorized}
    end
  end

  @doc "Get a single message with preloads."
  def get_message!(id) do
    Repo.get!(Message, id)
    |> Repo.preload([:sender, :attachments, :reactions, :statuses, reply_to: [:sender]])
  end

  # ──────────────────────────────────────────────────────────────────────────
  # Read receipts
  # ──────────────────────────────────────────────────────────────────────────

  @doc """
  Mark all messages in a conversation as read for the given user.
  Updates the participant's last_read_at and upserts message statuses.
  """
  def mark_as_read(conversation_id, user_id) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    # Get participant's previous last_read_at
    participant =
      Repo.one(
        from p in Participant,
          where: p.conversation_id == ^conversation_id and p.user_id == ^user_id
      )

    last_read_at = participant.last_read_at

    # Update participant's last_read_at
    Repo.update_all(
      from(p in Participant,
        where: p.conversation_id == ^conversation_id and p.user_id == ^user_id
      ),
      set: [last_read_at: now]
    )

    # Upsert "read" status for all messages in this conversation not sent by this user
    # and inserted after the previous last_read_at.
    query =
      from m in Message,
        where: m.conversation_id == ^conversation_id and m.sender_id != ^user_id

    query =
      if last_read_at do
        from m in query, where: m.inserted_at > ^last_read_at
      else
        query
      end

    message_ids = Repo.all(from m in query, select: m.id)

    for msg_id <- message_ids do
      upsert_message_status(msg_id, user_id, "read")
    end

    # Broadcast read receipt to conversation members
    broadcast_conversation(
      conversation_id,
      {:messages_read, %{user_id: user_id, conversation_id: conversation_id}}
    )

    :ok
  end

  @doc """
  Upserts a message status (delivered or read) for a specific user.
  """
  def upsert_message_status(message_id, user_id, status) do
    # "read" overrides "delivered"
    existing =
      Repo.one(
        from s in MessageStatus,
          where: s.message_id == ^message_id and s.user_id == ^user_id
      )

    case existing do
      nil ->
        %MessageStatus{}
        |> MessageStatus.changeset(%{message_id: message_id, user_id: user_id, status: status})
        |> Repo.insert()

      %{status: "read"} ->
        {:ok, existing}

      %{status: "delivered"} when status == "read" ->
        existing
        |> MessageStatus.changeset(%{status: "read"})
        |> Repo.update()

      _ ->
        {:ok, existing}
    end
    |> case do
      {:ok, status_record} ->
        message = get_message!(message_id)

        broadcast_conversation(
          message.conversation_id,
          {:message_status_updated, %{message_id: message_id, user_id: user_id, status: status}}
        )

        {:ok, status_record}

      error ->
        error
    end
  end

  @doc """
  Returns the aggregated status of a message.
  Returns "seen", "delivered", or "sent".
  """
  def get_message_aggregated_status(message) do
    # For direct chats:
    # - "seen" if the other participant has a "read" status.
    # - "delivered" if the other participant has a "delivered" status.
    # - "sent" otherwise.
    # For group chats:
    # - "seen" if ALL other participants have "read" status.
    # - "delivered" if ALL other participants have "delivered" status.
    # (Simplified for now: "seen" if at least one other has seen it,
    # "delivered" if at least one other has received it)

    statuses = message.statuses

    cond do
      Enum.any?(statuses, &(&1.status == "read")) -> "seen"
      Enum.any?(statuses, &(&1.status == "delivered")) -> "delivered"
      true -> "sent"
    end
  end

  @doc "Count unread messages in a conversation for a user."
  def get_unread_count(conversation_id, user_id) do
    participant =
      Repo.one(
        from p in Participant,
          where: p.conversation_id == ^conversation_id and p.user_id == ^user_id,
          select: p.last_read_at
      )

    case participant do
      nil ->
        0

      last_read_at ->
        query =
          from m in Message,
            where:
              m.conversation_id == ^conversation_id and
                m.sender_id != ^user_id and
                is_nil(m.deleted_at)

        query =
          if last_read_at do
            from m in query, where: m.inserted_at > ^last_read_at
          else
            query
          end

        Repo.aggregate(query, :count)
    end
  end

  # ──────────────────────────────────────────────────────────────────────────
  # Users / tenant-scoped
  # ──────────────────────────────────────────────────────────────────────────

  @doc "Gets the last time the user read any conversation"
  def get_user_last_seen(user_id) do
    query =
      from p in Participant,
        where: p.user_id == ^user_id,
        select: max(p.last_read_at)

    Repo.one(query)
  end

  @doc "List all users in the same tenant (for starting new DMs)."
  def list_users_for_chat(tenant_id, current_user_id) do
    Repo.all(
      from u in User,
        where: u.tenant_id == ^tenant_id and u.id != ^current_user_id and u.is_active == true,
        order_by: [asc: u.full_name]
    )
  end

  # ──────────────────────────────────────────────────────────────────────────
  # Attachments
  # ──────────────────────────────────────────────────────────────────────────

  @doc "Create an attachment record linked to a message."
  def create_attachment(attrs) do
    %Attachment{}
    |> Attachment.changeset(attrs)
    |> Repo.insert()
  end

  @doc "List todos for a conversation."
  def list_todos(conversation_id) do
    Repo.all(
      from t in Todo,
        where: t.conversation_id == ^conversation_id,
        order_by: [desc: t.inserted_at]
    )
  end

  @doc "List notes for a conversation."
  def list_notes(conversation_id) do
    Repo.all(
      from n in Note,
        where: n.conversation_id == ^conversation_id,
        order_by: [desc: n.inserted_at]
    )
  end

  @doc "Create a todo."
  def create_todo(attrs) do
    %Todo{}
    |> Todo.changeset(attrs)
    |> Repo.insert()
  end

  @doc "Update a todo."
  def update_todo(%Todo{} = todo, attrs) do
    todo
    |> Todo.changeset(attrs)
    |> Repo.update()
  end

  @doc "Create a note."
  def create_note(attrs) do
    %Note{}
    |> Note.changeset(attrs)
    |> Repo.insert()
  end

  @doc "List reactions for a message."
  def list_reactions(message_id) do
    Repo.all(
      from r in MessageReaction,
        where: r.message_id == ^message_id,
        join: u in assoc(r, :user),
        preload: [user: u]
    )
  end

  @doc "Add a reaction to a message."
  def add_reaction(message_id, user_id, emoji) do
    # Instagram logic: One user can have only one reaction per message
    Repo.delete_all(
      from r in MessageReaction,
        where: r.message_id == ^message_id and r.user_id == ^user_id
    )

    changeset =
      %MessageReaction{}
      |> MessageReaction.changeset(%{emoji: emoji, message_id: message_id, user_id: user_id})

    case Repo.insert(changeset) do
      {:ok, _reaction} ->
        message = get_message!(message_id)
        broadcast_conversation(message.conversation_id, {:message_updated, message})
        {:ok, message}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  @doc "Remove a reaction from a message."
  def remove_reaction(message_id, user_id, emoji) do
    Repo.delete_all(
      from r in MessageReaction,
        where: r.message_id == ^message_id and r.user_id == ^user_id and r.emoji == ^emoji
    )

    message = get_message!(message_id)
    broadcast_conversation(message.conversation_id, {:message_updated, message})

    {:ok, message}
  end

  @doc "Changeset for a new message (used in forms)."
  def change_message(%Message{} = message, attrs \\ %{}) do
    Message.changeset(message, attrs)
  end
end
