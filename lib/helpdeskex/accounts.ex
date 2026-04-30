defmodule Helpdeskex.Accounts do
  @moduledoc """
  The Accounts context.
  """

  import Ecto.Query, warn: false
  alias Helpdeskex.Repo

  alias Helpdeskex.Accounts.Tenant
  alias Helpdeskex.Accounts.User
  alias Helpdeskex.Accounts.Role
  alias Helpdeskex.Accounts.Team
  alias Helpdeskex.Accounts.Notification
  alias Helpdeskex.Accounts.AuditLog

  def subscribe(user_id) do
    Phoenix.PubSub.subscribe(Helpdeskex.PubSub, "notifications:#{user_id}")
  end

  defp broadcast_notification({:ok, notification}, user_id) do
    Phoenix.PubSub.broadcast(
      Helpdeskex.PubSub,
      "notifications:#{user_id}",
      {:new_notification, notification}
    )

    {:ok, notification}
  end

  defp broadcast_notification(error, _user_id), do: error

  # --- Tenants ---

  def list_tenants do
    Repo.all(Tenant)
  end

  def get_tenant!(id), do: Repo.get!(Tenant, id)

  def create_tenant(attrs \\ %{}) do
    %Tenant{}
    |> Tenant.changeset(attrs)
    |> Repo.insert()
  end

  # --- Users ---

  def list_users(tenant_id) do
    Repo.all(from u in User, where: u.tenant_id == ^tenant_id)
  end

  def get_user!(id), do: Repo.get!(User, id)

  def get_user_by_email(email) do
    Repo.get_by(User, email: email)
  end

  def authenticate_user(email, password) do
    with %User{} = user <- Repo.get_by(User, email: email),
         true <- Pbkdf2.verify_pass(password, user.password_hash) do
      {:ok, user}
    else
      _ -> {:error, :invalid_credentials}
    end
  end

  def create_user(attrs \\ %{}) do
    %User{}
    |> User.changeset(attrs)
    |> Repo.insert()
  end

  def deliver_user_reset_password_instructions(%User{} = user, reset_password_url_fun) do
    if user.is_active do
      token =
        Phoenix.Token.sign(
          HelpdeskexWeb.Endpoint,
          "user_pwd_reset",
          {user.id, user.password_hash}
        )

      Helpdeskex.Accounts.UserNotifier.deliver_reset_password_instructions(
        user,
        reset_password_url_fun.(token)
      )
    end

    {:ok, :instructions_sent}
  end

  def update_user_password(%User{} = user, password) do
    user
    |> User.changeset(%{password: password})
    |> Repo.update()
  end

  # --- Roles ---

  def list_roles(tenant_id) do
    Repo.all(from r in Role, where: r.tenant_id == ^tenant_id)
  end

  def create_role(attrs \\ %{}) do
    %Role{}
    |> Role.changeset(attrs)
    |> Repo.insert()
  end

  # --- Teams ---

  def list_teams(tenant_id) do
    Repo.all(from t in Team, where: t.tenant_id == ^tenant_id)
  end

  def create_team(attrs \\ %{}) do
    %Team{}
    |> Team.changeset(attrs)
    |> Repo.insert()
  end

  # --- Notifications ---

  def list_unread_notifications(user_id) do
    Repo.all(
      from n in Notification,
        where: n.user_id == ^user_id and n.is_read == false,
        order_by: [desc: n.inserted_at]
    )
  end

  def create_notification(attrs \\ %{}) do
    %Notification{}
    |> Notification.changeset(attrs)
    |> Repo.insert()
    |> broadcast_notification(attrs[:user_id] || attrs["user_id"])
  end

  def mark_all_as_read(user_id) do
    from(n in Notification, where: n.user_id == ^user_id)
    |> Repo.update_all(set: [is_read: true])
  end

  # --- Audit Logs ---

  def list_audit_logs(resource_type, resource_id) do
    Repo.all(
      from l in AuditLog,
        where: l.resource_type == ^resource_type and l.resource_id == ^resource_id,
        order_by: [desc: l.inserted_at],
        preload: [:user]
    )
  end

  def log_action(attrs) do
    %AuditLog{}
    |> AuditLog.changeset(attrs)
    |> Repo.insert()
  end
end
