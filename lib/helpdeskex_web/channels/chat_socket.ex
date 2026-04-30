defmodule HelpdeskexWeb.ChatSocket do
  use Phoenix.Socket

  # Channels
  channel "conversation:*", HelpdeskexWeb.ConversationChannel
  channel "user:*", HelpdeskexWeb.UserChannel

  @max_age 86_400

  @impl true
  def connect(%{"token" => token}, socket, _connect_info) do
    case Phoenix.Token.verify(HelpdeskexWeb.Endpoint, "chat_socket", token, max_age: @max_age) do
      {:ok, user_id} ->
        {:ok, assign(socket, :user_id, user_id)}

      {:error, _reason} ->
        :error
    end
  end

  def connect(_params, _socket, _connect_info), do: :error

  @impl true
  def id(socket), do: "chat_socket:#{socket.assigns.user_id}"
end
