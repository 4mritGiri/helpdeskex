defmodule HelpdeskexWeb.UserChannel do
  @moduledoc """
  Personal channel for a user.
  Topic: "user:{user_id}"

  Broadcasts personal events: new conversation invitations, notifications.
  """
  use HelpdeskexWeb, :channel

  @impl true
  def join("user:" <> user_id, _payload, socket) do
    if socket.assigns.user_id == user_id do
      {:ok, socket}
    else
      {:error, %{reason: "unauthorized"}}
    end
  end
end
