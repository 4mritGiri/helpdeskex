# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     Helpdeskex.Repo.insert!(%Helpdeskex.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

alias Helpdeskex.Repo
alias Helpdeskex.Accounts.{Tenant, User, Role, Team}
alias Helpdeskex.Tickets.{TicketStatus, TicketPriority, Ticket}

Repo.delete_all(Ticket)
Repo.delete_all(TicketPriority)
Repo.delete_all(TicketStatus)
Repo.delete_all(Team)
Repo.delete_all(Role)
Repo.delete_all(User)
Repo.delete_all(Tenant)

# 1. Create a Tenant
tenant =
  Repo.insert!(%Tenant{
    name: "Acme Corp (Banking)",
    plan: "enterprise",
    is_active: true
  })

# 2. Create Roles
admin_role =
  Repo.insert!(%Role{
    tenant_id: tenant.id,
    name: "Admin",
    permissions: %{"all" => true}
  })

agent_role =
  Repo.insert!(%Role{
    tenant_id: tenant.id,
    name: "Agent",
    permissions: %{"tickets" => "write"}
  })

# 3. Create Users
admin_user =
  Repo.insert!(%User{
    tenant_id: tenant.id,
    email: "admin@acme.com",
    password_hash: Pbkdf2.hash_pwd_salt("password123"),
    full_name: "Admin User",
    is_active: true
  })

agent_user =
  Repo.insert!(%User{
    tenant_id: tenant.id,
    email: "agent@acme.com",
    password_hash: Pbkdf2.hash_pwd_salt("password123"),
    full_name: "Support Agent",
    is_active: true
  })

customer_user =
  Repo.insert!(%User{
    tenant_id: tenant.id,
    email: "customer@bank.com",
    password_hash: Pbkdf2.hash_pwd_salt("password123"),
    full_name: "Jane Customer",
    is_active: true
  })

# 4. Create Ticket Statuses
status_open =
  Repo.insert!(%TicketStatus{
    tenant_id: tenant.id,
    name: "open",
    order_index: 1
  })

status_in_progress =
  Repo.insert!(%TicketStatus{
    tenant_id: tenant.id,
    name: "in_progress",
    order_index: 2
  })

status_resolved =
  Repo.insert!(%TicketStatus{
    tenant_id: tenant.id,
    name: "resolved",
    order_index: 3
  })

# 5. Create Ticket Priorities
priority_urgent =
  Repo.insert!(%TicketPriority{
    tenant_id: tenant.id,
    name: "urgent",
    sla_hours: 4
  })

priority_high =
  Repo.insert!(%TicketPriority{
    tenant_id: tenant.id,
    name: "high",
    sla_hours: 12
  })

priority_medium =
  Repo.insert!(%TicketPriority{
    tenant_id: tenant.id,
    name: "medium",
    sla_hours: 24
  })

priority_low =
  Repo.insert!(%TicketPriority{
    tenant_id: tenant.id,
    name: "low",
    sla_hours: 48
  })

# 6. Create Tickets
Repo.insert!(%Ticket{
  tenant_id: tenant.id,
  subject: "Unable to process wire transfer",
  description: "The transaction fails with an obscure error code 'ERR_503_BANK_OP'.",
  status_id: status_open.id,
  priority_id: priority_urgent.id,
  requester_id: customer_user.id,
  assigned_to_id: agent_user.id
})

Repo.insert!(%Ticket{
  tenant_id: tenant.id,
  subject: "Password reset for admin portal",
  description: "I lost my 2FA device and cannot login.",
  status_id: status_open.id,
  priority_id: priority_high.id,
  requester_id: customer_user.id,
  assigned_to_id: admin_user.id
})

Repo.insert!(%Ticket{
  tenant_id: tenant.id,
  subject: "New feature request: Export to PDF",
  description: "It would be great to export statements to PDF.",
  status_id: status_in_progress.id,
  priority_id: priority_medium.id,
  requester_id: customer_user.id,
  assigned_to_id: agent_user.id
})

Repo.insert!(%Ticket{
  tenant_id: tenant.id,
  subject: "Slow loading on dashboard",
  description: "The dashboard takes 5 seconds to load.",
  status_id: status_in_progress.id,
  priority_id: priority_low.id,
  requester_id: customer_user.id,
  assigned_to_id: agent_user.id
})

# 7. Create Workflow Rules
Repo.insert!(%Helpdeskex.Tickets.WorkflowRule{
  tenant_id: tenant.id,
  name: "Auto-Urgent for Critical Issues",
  trigger_event: "ticket_created",
  conditions: %{"subject_contains" => "critical"},
  actions: %{"set_priority_by_name" => "urgent"},
  is_active: true
})

# 8. Create SLA Policies
Repo.insert!(%Helpdeskex.Tickets.SlaPolicy{
  tenant_id: tenant.id,
  name: "Standard Banking SLA",
  response_time_minutes: 60,
  resolution_time_minutes: 240
})

IO.puts(
  "Database seeded successfully with Acme Corp tenant, users, statuses, priorities, workflow rules, SLA policies, and 4 sample tickets!"
)
