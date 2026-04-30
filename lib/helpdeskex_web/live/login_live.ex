defmodule HelpdeskexWeb.LoginLive do
  use HelpdeskexWeb, :live_view

  @dev_routes Application.compile_env(:helpdeskex, :dev_routes, false)

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Login · HelpdeskEx")
     |> assign(:form, to_form(%{"email" => "", "password" => ""}))
     |> assign(:dev_routes, @dev_routes)
     |> assign(:passkey_id, nil)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen flex items-center justify-center relative bg-slate-100 dark:bg-zinc-950 font-sans overflow-hidden">
      <%!-- Subtle background texture — never distracting --%>
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

      <%!-- Compact card that fits any standard viewport --%>
      <div class="relative z-10 w-full max-w-md mx-auto px-4">
        <div class="bg-white/90 dark:bg-zinc-900/80 backdrop-blur-xl rounded-3xl shadow-xl shadow-slate-200/60 dark:shadow-black/60 border border-slate-200/80 dark:border-white/[0.07] overflow-hidden">
          <%!-- Card Header --%>
          <div class="px-8 pt-7 pb-5 border-b border-slate-100 dark:border-white/[0.05] flex items-center gap-4">
            <div class="relative size-14 rounded-2xl bg-white/[0.03] border border-white/10 flex items-center justify-center shadow-inner overflow-hidden">
              <div class="absolute inset-0 bg-gradient-to-tr from-indigo-500/10 to-transparent"></div>
              <span class="text-xl font-black text-white tracking-tighter leading-none">
                H<span class="text-indigo-500">X</span>
              </span>
            </div>
            <div>
              <h1 class="text-lg font-bold text-slate-900 dark:text-white leading-tight">
                Welcome back
              </h1>
              <p class="text-xs text-slate-400 dark:text-zinc-500 font-medium mt-0.5">
                Sign in to HelpdeskEx
              </p>
            </div>
          </div>

          <%!-- Form Body --%>
          <div class="px-8 py-6">
            <%= if flash = @flash["error"] do %>
              <div class="mb-4 px-4 py-2.5 rounded-xl bg-red-50 dark:bg-red-900/20 border border-red-200 dark:border-red-500/20 flex items-center gap-2.5">
                <div class="size-1.5 rounded-full bg-red-500 flex-shrink-0"></div>
                <span class="text-xs font-semibold text-red-600 dark:text-red-400">{flash}</span>
              </div>
            <% end %>

            <form method="post" action="/session" class="space-y-4">
              <input type="hidden" name="_csrf_token" value={Plug.CSRFProtection.get_csrf_token()} />

              <div>
                <label class="block text-[11px] font-bold text-slate-500 dark:text-zinc-400 uppercase tracking-wider mb-1.5">
                  Email
                </label>
                <div class="relative">
                  <div class="absolute inset-y-0 left-3 flex items-center pointer-events-none text-slate-400 dark:text-zinc-500">
                    <.icon name="hero-envelope" class="size-4" />
                  </div>
                  <input
                    id="email"
                    type="email"
                    name="email"
                    placeholder="you@company.com"
                    autocomplete="email"
                    class="w-full bg-slate-50 dark:bg-zinc-800/60 border border-slate-200 dark:border-zinc-700/60 rounded-xl py-2.5 pl-9 pr-3 text-sm text-slate-900 dark:text-white placeholder:text-slate-400 dark:placeholder:text-zinc-600 focus:outline-none focus:ring-2 focus:ring-indigo-500/30 focus:border-indigo-400 dark:focus:border-indigo-500/50 transition-all"
                    required
                  />
                </div>
              </div>

              <div>
                <div class="flex items-center justify-between mb-1.5">
                  <label class="block text-[11px] font-bold text-slate-500 dark:text-zinc-400 uppercase tracking-wider">
                    Password
                  </label>
                  <.link
                    navigate="/users/reset_password"
                    class="text-[11px] font-semibold text-indigo-600 dark:text-indigo-400 hover:text-indigo-500 transition-colors"
                  >
                    Forgot?
                  </.link>
                </div>
                <div class="relative">
                  <div class="absolute inset-y-0 left-3 flex items-center pointer-events-none text-slate-400 dark:text-zinc-500">
                    <.icon name="hero-lock-closed" class="size-4" />
                  </div>
                  <input
                    id="password"
                    type="password"
                    name="password"
                    placeholder="••••••••"
                    autocomplete="current-password"
                    class="w-full bg-slate-50 dark:bg-zinc-800/60 border border-slate-200 dark:border-zinc-700/60 rounded-xl py-2.5 pl-9 pr-3 text-sm text-slate-900 dark:text-white placeholder:text-slate-400 dark:placeholder:text-zinc-600 focus:outline-none focus:ring-2 focus:ring-indigo-500/30 focus:border-indigo-400 dark:focus:border-indigo-500/50 transition-all"
                    required
                  />
                </div>
              </div>

              <button
                type="submit"
                class="w-full bg-indigo-600 hover:bg-indigo-500 text-white text-sm font-bold py-2.5 rounded-xl shadow-md shadow-indigo-500/20 transition-all active:scale-[0.98] flex items-center justify-center gap-2"
              >
                Sign In <.icon name="hero-arrow-right" class="size-4" />
              </button>
            </form>

            <%!-- Or divider --%>
            <div class="flex items-center gap-3 my-4">
              <div class="flex-1 h-px bg-slate-200 dark:bg-zinc-700/50"></div>
              <span class="text-[10px] font-bold text-slate-400 dark:text-zinc-600 uppercase tracking-wider">
                or
              </span>
              <div class="flex-1 h-px bg-slate-200 dark:bg-zinc-700/50"></div>
            </div>

            <%!-- Passkey --%>
            <div id="passkey-container" phx-hook="Passkey">
              <button
                type="button"
                phx-click="start-passkey-login"
                class="w-full bg-slate-50 dark:bg-zinc-800/40 hover:bg-slate-100 dark:hover:bg-zinc-800 text-slate-600 dark:text-zinc-400 border border-slate-200 dark:border-zinc-700/50 py-2.5 rounded-xl text-xs font-semibold flex items-center justify-center gap-2 transition-all"
              >
                <.icon name="hero-finger-print" class="size-4 text-indigo-500" />
                Continue with Biometrics
              </button>

              <form id="passkey-form" method="post" action="/session" style="display:none;">
                <input type="hidden" name="_csrf_token" value={Plug.CSRFProtection.get_csrf_token()} />
                <input type="hidden" name="passkey_id" value={@passkey_id} />
              </form>
            </div>
          </div>

          <%= if @dev_routes do %>
            <%!-- Demo Credentials Strip --%>
            <div class="px-8 py-3.5 bg-slate-50/80 dark:bg-zinc-800/30 border-t border-slate-100 dark:border-white/[0.04] flex items-center gap-3">
              <div class="size-1.5 rounded-full bg-green-400 animate-pulse flex-shrink-0"></div>
              <div class="flex flex-wrap items-center gap-x-1.5 gap-y-0.5 text-[11px]">
                <span class="text-slate-400 dark:text-zinc-500 font-medium">Demo:</span>
                <span class="font-semibold text-slate-700 dark:text-zinc-300">admin@acme.com</span>
                <span class="text-slate-300 dark:text-zinc-600">/</span>
                <span class="font-semibold text-slate-700 dark:text-zinc-300">password123</span>
              </div>
            </div>
          <% end %>
        </div>

        <p class="text-center text-[10px] text-slate-400 dark:text-zinc-600 font-medium mt-4 tracking-wide">
          &copy; 2026 HelpdeskEx &mdash; All rights reserved
        </p>
      </div>
    </div>
    """
  end

  @impl true
  def handle_event("start-passkey-login", _, socket) do
    challenge = Helpdeskex.Accounts.PasskeyAuth.generate_challenge()
    {:noreply, push_event(socket, "login-passkey", %{challenge: challenge})}
  end

  @impl true
  def handle_event("passkey-login-ready", %{"id" => id}, socket) do
    # Assign ID so it populates the hidden form, then trigger form submit
    {:noreply,
     socket
     |> assign(:passkey_id, id)
     |> push_js("#passkey-form", "submit")}
  end

  defp push_js(socket, selector, action) do
    push_event(socket, "js-exec", %{selector: selector, action: action})
  end
end
