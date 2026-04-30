defmodule HelpdeskexWeb.ForgotPasswordLive do
  use HelpdeskexWeb, :live_view

  alias Helpdeskex.Accounts

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, form: to_form(%{"email" => ""}))}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen flex items-center justify-center relative bg-slate-100 dark:bg-zinc-950 font-sans overflow-hidden transition-colors duration-700">
      <%!-- Background --%>
      <div class="absolute inset-0 pointer-events-none">
        <img
          src="/images/login_bg_light.png"
          class="w-full h-full object-cover opacity-30 dark:hidden scale-110"
          style="filter: blur(30px);"
        />
        <img
          src="/images/login_bg.png"
          class="w-full h-full object-cover opacity-25 hidden dark:block scale-110"
          style="filter: blur(60px) saturate(1.3);"
        />
        <div class="absolute inset-0 bg-gradient-to-br from-white/60 via-transparent to-indigo-50/30 dark:from-black/80 dark:via-transparent dark:to-indigo-950/30">
        </div>
      </div>

      <div class="relative z-10 w-full max-w-sm mx-auto px-4">
        <div class="bg-white/90 dark:bg-zinc-900/80 backdrop-blur-xl rounded-3xl shadow-xl shadow-slate-200/60 dark:shadow-black/60 border border-slate-200/80 dark:border-white/[0.07] overflow-hidden">
          <%!-- Card Header --%>
          <div class="px-8 pt-7 pb-5 border-b border-slate-100 dark:border-white/[0.05] flex items-center gap-4">
            <div class="size-10 rounded-xl bg-indigo-600 flex items-center justify-center shadow-lg shadow-indigo-500/30 flex-shrink-0">
              <.icon name="hero-key" class="size-5 text-white" />
            </div>
            <div>
              <h1 class="text-lg font-bold text-slate-900 dark:text-white leading-tight">
                Forgot password?
              </h1>
              <p class="text-xs text-slate-400 dark:text-zinc-500 font-medium mt-0.5">
                We'll send you reset instructions.
              </p>
            </div>
          </div>

          <div class="px-8 py-6">
            <.form for={@form} id="reset_password_form" phx-submit="send_email" class="space-y-4">
              <div>
                <label class="block text-[11px] font-bold text-slate-500 dark:text-zinc-400 uppercase tracking-wider mb-1.5 ml-0.5">
                  Email
                </label>
                <div class="relative">
                  <div class="absolute inset-y-0 left-3.5 flex items-center pointer-events-none text-slate-400 dark:text-zinc-500">
                    <.icon name="hero-envelope" class="size-4" />
                  </div>
                  <.input
                    field={@form[:email]}
                    type="email"
                    placeholder="you@company.com"
                    autocomplete="email"
                    class="w-full bg-slate-50 dark:bg-zinc-800/60 border border-slate-200 dark:border-zinc-700/60 rounded-xl py-2.5 pl-10 pr-4 text-sm text-slate-900 dark:text-white placeholder:text-slate-400 dark:placeholder:text-zinc-600 focus:outline-none focus:ring-2 focus:ring-indigo-500/30 focus:border-indigo-400 dark:focus:border-indigo-500/50 transition-all"
                    required
                  />
                </div>
              </div>

              <button
                type="submit"
                phx-disable-with="Sending..."
                class="w-full bg-indigo-600 hover:bg-indigo-500 text-white text-sm font-bold py-2.5 rounded-xl shadow-md shadow-indigo-500/20 transition-all active:scale-[0.98] flex items-center justify-center gap-2 mt-1"
              >
                Send instructions <.icon name="hero-paper-airplane" class="size-4" />
              </button>
            </.form>

            <div class="mt-6 text-center">
              <.link
                navigate="/login"
                class="text-xs font-semibold text-slate-500 dark:text-zinc-400 hover:text-indigo-600 dark:hover:text-indigo-400 transition-colors flex items-center justify-center gap-1.5"
              >
                <.icon name="hero-arrow-left" class="size-3.5" /> Back to sign in
              </.link>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  @impl true
  def handle_event("send_email", %{"email" => email}, socket) do
    if user = Accounts.get_user_by_email(email) do
      Accounts.deliver_user_reset_password_instructions(user, fn token ->
        url(~p"/users/reset_password/#{token}")
      end)
    end

    info = "If your email is in our system, you will receive instructions shortly."

    {:noreply,
     socket
     |> put_flash(:info, info)
     |> redirect(to: "/login")}
  end
end
