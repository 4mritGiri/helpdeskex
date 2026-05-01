defmodule HelpdeskexWeb.RegisterLive do
  use HelpdeskexWeb, :live_view

  alias Helpdeskex.Accounts
  alias Helpdeskex.Accounts.User

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Register · HelpdeskEx")
     |> assign(:form, to_form(Accounts.User.changeset(%User{}, %{})))}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen flex items-center justify-center relative bg-slate-100 dark:bg-zinc-950 font-sans overflow-hidden">
      <div class="absolute inset-0 pointer-events-none">
        <img
          src="/images/login_bg.png"
          class="w-full h-full object-cover opacity-20 scale-110 blur-[60px]"
        />
      </div>

      <div class="relative z-10 w-full max-w-md mx-auto px-4">
        <div class="bg-white/90 dark:bg-zinc-900/80 backdrop-blur-xl rounded-3xl shadow-xl border border-slate-200/80 dark:border-white/[0.07] overflow-hidden">
          <div class="px-8 pt-7 pb-5 border-b border-slate-100 dark:border-white/[0.05] flex items-center gap-4">
            <div class="relative size-14 rounded-2xl bg-indigo-500 flex items-center justify-center shadow-lg overflow-hidden shrink-0">
              <span class="text-xl font-black text-white tracking-tighter">HX</span>
            </div>
            <div>
              <h1 class="text-lg font-bold text-slate-900 dark:text-white leading-tight">
                Create Account
              </h1>
              <p class="text-xs text-slate-400 dark:text-zinc-500 font-medium">
                Join the HelpdeskEx platform
              </p>
            </div>
          </div>

          <div class="px-8 py-6">
            <.form
              for={@form}
              id="registration-form"
              phx-change="validate"
              phx-submit="save"
              class="space-y-4"
            >
              <div>
                <label class="block text-[11px] font-bold text-slate-500 dark:text-zinc-400 uppercase tracking-wider mb-1.5">
                  Full Name
                </label>
                <.input
                  field={@form[:full_name]}
                  type="text"
                  placeholder="John Doe"
                  required
                  class="reg-input"
                />
              </div>

              <div>
                <label class="block text-[11px] font-bold text-slate-500 dark:text-zinc-400 uppercase tracking-wider mb-1.5">
                  Email
                </label>
                <.input
                  field={@form[:email]}
                  type="email"
                  placeholder="john@example.com"
                  required
                  class="reg-input"
                />
              </div>

              <div>
                <label class="block text-[11px] font-bold text-slate-500 dark:text-zinc-400 uppercase tracking-wider mb-1.5">
                  Password
                </label>
                <.input
                  field={@form[:password]}
                  type="password"
                  placeholder="••••••••"
                  required
                  class="reg-input"
                />
              </div>

              <div class="pt-2">
                <button
                  type="submit"
                  class="w-full bg-indigo-600 hover:bg-indigo-500 text-white text-sm font-bold py-3 rounded-xl shadow-lg transition-all active:scale-[0.98]"
                >
                  Start Free Trial
                </button>
              </div>
            </.form>

            <div class="mt-6 text-center">
              <p class="text-xs text-slate-500 dark:text-zinc-500">
                Already have an account?
                <.link
                  navigate="/login"
                  class="text-indigo-600 dark:text-indigo-400 font-bold hover:underline"
                >
                  Sign In
                </.link>
              </p>
            </div>
          </div>
        </div>
      </div>
    </div>

    <style>
      .reg-input {
        @apply w-full bg-slate-50 dark:bg-zinc-800/60 border border-slate-200 dark:border-zinc-700/60 rounded-xl py-2.5 px-4 text-sm text-slate-900 dark:text-white placeholder:text-slate-400 dark:placeholder:text-zinc-600 focus:outline-none focus:ring-2 focus:ring-indigo-500/30 focus:border-indigo-400 dark:focus:border-indigo-500/50 transition-all;
      }
    </style>
    """
  end

  @impl true
  def handle_event("validate", %{"user" => user_params}, socket) do
    form =
      %User{}
      |> Accounts.User.changeset(user_params)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, form: form)}
  end

  @impl true
  def handle_event("save", %{"user" => user_params}, socket) do
    # For demo purposes, we assign to the first tenant found
    tenant = List.first(Accounts.list_tenants())
    user_params = Map.put(user_params, "tenant_id", tenant.id)

    case Accounts.create_user(user_params) do
      {:ok, _user} ->
        {:noreply,
         socket
         |> put_flash(:info, "Account created! You can now log in.")
         |> push_navigate(to: "/login")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end
end
