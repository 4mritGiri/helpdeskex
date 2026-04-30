defmodule Helpdeskex.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "users" do
    field :email, :string
    field :password_hash, :string
    field :full_name, :string
    field :is_active, :boolean, default: true
    field :password, :string, virtual: true

    belongs_to :tenant, Helpdeskex.Accounts.Tenant

    many_to_many :roles, Helpdeskex.Accounts.Role, join_through: "user_roles"
    many_to_many :teams, Helpdeskex.Accounts.Team, join_through: "team_members"
    has_many :passkeys, Helpdeskex.Accounts.UserPasskey

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(user, attrs) do
    user
    |> cast(attrs, [:email, :full_name, :is_active, :tenant_id, :password])
    |> validate_required([:email, :tenant_id])
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/, message: "must have the @ sign and no spaces")
    |> unique_constraint([:tenant_id, :email])
    |> put_password_hash()
  end

  defp put_password_hash(
         %Ecto.Changeset{valid?: true, changes: %{password: password}} = changeset
       ) do
    put_change(changeset, :password_hash, Pbkdf2.hash_pwd_salt(password))
  end

  defp put_password_hash(changeset), do: changeset
end
