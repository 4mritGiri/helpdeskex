defmodule HelpdeskexWeb.Router do
  use HelpdeskexWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {HelpdeskexWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  # Guardian auth pipeline (loads current user if token exists)
  pipeline :auth do
    plug HelpdeskexWeb.Auth.Pipeline
  end

  # Require a logged-in user
  pipeline :require_auth do
    plug Guardian.Plug.EnsureAuthenticated, error_handler: HelpdeskexWeb.Auth.ErrorHandler
  end

  # Public routes (login page, session create/delete)
  scope "/", HelpdeskexWeb do
    pipe_through [:browser, :auth]

    live "/login", LoginLive
    live "/users/reset_password", ForgotPasswordLive
    live "/users/reset_password/:token", ResetPasswordLive
    post "/session", SessionController, :create
    delete "/session", SessionController, :delete
  end

  # Protected routes (require authentication)
  scope "/", HelpdeskexWeb do
    pipe_through [:browser, :auth, :require_auth]

    live "/", DashboardLive
  end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:helpdeskex, :dev_routes) do
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: HelpdeskexWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
