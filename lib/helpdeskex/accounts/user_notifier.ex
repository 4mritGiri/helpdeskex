defmodule Helpdeskex.Accounts.UserNotifier do
  import Swoosh.Email

  alias Helpdeskex.Mailer

  # Delivers the email for the password reset instructions
  def deliver_reset_password_instructions(user, url) do
    deliver(user.email, "Reset password instructions", """

    ==============================

    Hi #{user.full_name},

    You can reset your password by visiting the URL below:

    #{url}

    If you didn't create this request, please ignore this.

    ==============================
    """)
  end

  defp deliver(recipient, subject, body) do
    email =
      new()
      |> to(recipient)
      |> from({"HelpdeskEx", "notifications@helpdeskex.com"})
      |> subject(subject)
      |> text_body(body)

    with {:ok, _metadata} <- Mailer.deliver(email) do
      {:ok, email}
    end
  end
end
