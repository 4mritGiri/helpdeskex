defmodule HelpdeskexWeb.Auth.Pipeline do
  use Guardian.Plug.Pipeline,
    otp_app: :helpdeskex,
    module: Helpdeskex.Accounts.Guardian,
    error_handler: HelpdeskexWeb.Auth.ErrorHandler

  # Load the token from the session cookie (for browser/LiveView)
  plug Guardian.Plug.VerifySession, claims: %{"typ" => "access"}
  # Optionally load from Authorization header (for API)
  plug Guardian.Plug.VerifyHeader, claims: %{"typ" => "access"}
  # If a token was found, load the resource (User)
  plug Guardian.Plug.LoadResource, allow_blank: true
end
