defmodule HelpdeskexWeb.SessionController do
  use HelpdeskexWeb, :controller

  alias Helpdeskex.Accounts
  alias Helpdeskex.Accounts.Guardian

  def delete(conn, _params) do
    conn
    |> Guardian.Plug.sign_out()
    |> redirect(to: ~p"/login")
  end

  def create(conn, %{"passkey_id" => passkey_id}) when passkey_id != "" do
    case Helpdeskex.Accounts.PasskeyAuth.authenticate_via_passkey(passkey_id) do
      {:ok, user} ->
        conn
        |> Guardian.Plug.sign_in(user)
        |> redirect(to: ~p"/")

      {:error, _} ->
        conn
        |> put_flash(:error, "Passkey authentication failed.")
        |> redirect(to: ~p"/login")
    end
  end

  def create(conn, %{"email" => email, "password" => password}) do
    case Accounts.authenticate_user(email, password) do
      {:ok, user} ->
        conn
        |> Guardian.Plug.sign_in(user)
        |> redirect(to: ~p"/")

      {:error, _reason} ->
        conn
        |> put_flash(:error, "Invalid email or password.")
        |> redirect(to: ~p"/login")
    end
  end
end
