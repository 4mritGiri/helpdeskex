defmodule Helpdeskex.Repo do
  use Ecto.Repo,
    otp_app: :helpdeskex,
    adapter: Ecto.Adapters.SQLite3
end
