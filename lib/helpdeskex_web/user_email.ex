defmodule HelpdeskexWeb.UserEmail do
  import Swoosh.Email

  def ticket_assigned(user, ticket) do
    new()
    |> to({user.full_name, user.email})
    |> from({"HelpdeskEx", "notifications@helpdeskex.com"})
    |> subject("New Ticket Assigned: #{ticket.subject}")
    |> html_body("""
      <div style="font-family: sans-serif; max-width: 600px; margin: 0 auto; padding: 20px; border: 1px solid #eee; border-radius: 10px;">
        <h2 style="color: #2563eb;">New Ticket Assignment</h2>
        <p>Hello #{user.full_name},</p>
        <p>A new ticket has been assigned to you:</p>
        <div style="background: #f9fafb; padding: 15px; border-radius: 8px; margin: 20px 0;">
          <strong style="display: block; margin-bottom: 5px;">#{ticket.subject}</strong>
          <span style="color: #6b7280; font-size: 0.9rem;">Ticket ID: #{ticket.id}</span>
        </div>
        <p>Log in to your dashboard to view the details and start working on it.</p>
        <a href="http://localhost:4000" style="display: inline-block; background: #2563eb; color: white; padding: 10px 20px; border-radius: 6px; text-decoration: none; font-weight: bold;">View Dashboard</a>
        <hr style="border: none; border-top: 1px solid #eee; margin: 30px 0;" />
        <p style="font-size: 0.8rem; color: #9ca3af;">This is an automated notification from HelpdeskEx.</p>
      </div>
    """)
  end
end
