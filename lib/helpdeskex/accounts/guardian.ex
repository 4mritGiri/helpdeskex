defmodule Helpdeskex.Accounts.Guardian do
  use Guardian, otp_app: :helpdeskex

  alias Helpdeskex.Accounts.User
  alias Helpdeskex.Repo

  @impl true
  def subject_for_token(%User{id: id}, _claims) do
    {:ok, id}
  end

  def subject_for_token(_, _) do
    {:error, :unsupported_resource}
  end

  @impl true
  def resource_from_claims(%{"sub" => id}) do
    case Repo.get(User, id) do
      nil -> {:error, :resource_not_found}
      user -> {:ok, user}
    end
  end

  def resource_from_claims(_), do: {:error, :no_subject}
end
