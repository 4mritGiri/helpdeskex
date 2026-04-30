defmodule Helpdeskex.Chat.Presence do
  @moduledoc """
  Tracks user presence for the chat system.

  Provides online/offline status, typing indicators, and last seen timestamps.
  """
  use Phoenix.Presence,
    otp_app: :helpdeskex,
    pubsub_server: Helpdeskex.PubSub
end
