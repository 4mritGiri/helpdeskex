defmodule HelpdeskexWeb.Auth.ErrorHandler do
  import Plug.Conn
  import Phoenix.Controller

  @behaviour Guardian.Plug.ErrorHandler

  @impl Guardian.Plug.ErrorHandler
  def auth_error(conn, {type, _reason}, _opts) do
    conn
    |> put_flash(:error, to_string(type))
    |> redirect(to: "/login")
    |> halt()
  end
end
