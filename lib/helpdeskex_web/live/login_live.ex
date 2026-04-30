defmodule HelpdeskexWeb.LoginLive do
  use HelpdeskexWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Login · HelpdeskEx")
     |> assign(:form, to_form(%{"email" => "", "password" => ""}))
     |> assign(:passkey_id, nil)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen flex items-center justify-center relative overflow-hidden bg-zinc-950 font-sans">
      <%!-- Dynamic Background Image --%>
      <div class="absolute inset-0 z-0">
        <img
          src="/images/login_bg.png"
          class="w-full h-full object-cover opacity-60 scale-105 animate-pulse"
          style="filter: blur(40px); animation-duration: 8s;"
        />
        <div class="absolute inset-0 bg-gradient-to-tr from-zinc-950 via-transparent to-zinc-950">
        </div>
      </div>

      <%!-- Floating Decorative Elements --%>
      <div class="absolute top-1/4 -left-20 w-96 h-96 bg-purple-600/20 rounded-full blur-[100px] animate-blob">
      </div>
      <div class="absolute bottom-1/4 -right-20 w-96 h-96 bg-blue-600/20 rounded-full blur-[100px] animate-blob animation-delay-2000">
      </div>

      <div class="relative z-10 w-full max-w-[440px] px-6">
        <%!-- Login Card --%>
        <div class="backdrop-blur-2xl bg-zinc-900/65 border border-white/10 rounded-3xl p-8 md:p-12 shadow-2xl shadow-black/50">
          <div class="flex flex-col items-center mb-10">
            <div class="size-16 mb-6 rounded-2xl bg-gradient-to-br from-indigo-500 to-purple-600 flex items-center justify-center p-0.5 shadow-lg shadow-indigo-500/20 ring-1 ring-white/20">
              <div class="size-full bg-zinc-900 rounded-[14px] flex items-center justify-center text-2xl font-bold text-white tracking-tighter">
                H<span class="text-indigo-500">X</span>
              </div>
            </div>
            <h1 class="text-3xl font-bold text-white tracking-tight mb-2">Welcome back</h1>
            <p class="text-zinc-400 text-center text-sm font-medium">
              Sign in to your helpdesk workspace
            </p>
          </div>

          <%= if flash = @flash["error"] do %>
            <div class="mb-6 p-4 rounded-xl bg-red-500/10 border border-red-500/20 flex items-center gap-3 animate-shake">
              <.icon name="hero-exclamation-circle" class="size-5 text-red-500" />
              <p class="text-sm font-medium text-red-400">{flash}</p>
            </div>
          <% end %>

          <form method="post" action="/session" class="space-y-6">
            <input type="hidden" name="_csrf_token" value={Plug.CSRFProtection.get_csrf_token()} />

            <div class="space-y-2">
              <label class="block text-xs font-bold text-zinc-500 uppercase tracking-widest ml-1">
                Email Address
              </label>
              <div class="relative group">
                <div class="absolute inset-y-0 left-0 pl-4 flex items-center pointer-events-none transition-colors group-focus-within:text-indigo-500 text-zinc-500">
                  <.icon name="hero-envelope" class="size-5" />
                </div>
                <input
                  id="email"
                  type="email"
                  name="email"
                  placeholder="you@company.com"
                  autocomplete="email"
                  class="w-full bg-zinc-800/50 border border-zinc-700/50 rounded-xl py-3 pl-11 pr-4 text-white placeholder:text-zinc-600 focus:outline-none focus:ring-2 focus:ring-indigo-500/40 focus:border-indigo-500/50 transition-all"
                  required
                />
              </div>
            </div>

            <div class="space-y-2">
              <div class="flex items-center justify-between ml-1">
                <label class="block text-xs font-bold text-zinc-500 uppercase tracking-widest">
                  Password
                </label>
                <a
                  href="#"
                  class="text-xs font-semibold text-indigo-400 hover:text-indigo-300 transition-colors"
                >
                  Forgot?
                </a>
              </div>
              <div class="relative group">
                <div class="absolute inset-y-0 left-0 pl-4 flex items-center pointer-events-none transition-colors group-focus-within:text-indigo-500 text-zinc-500">
                  <.icon name="hero-lock-closed" class="size-5" />
                </div>
                <input
                  id="password"
                  type="password"
                  name="password"
                  placeholder="••••••••"
                  autocomplete="current-password"
                  class="w-full bg-zinc-800/50 border border-zinc-700/50 rounded-xl py-3 pl-11 pr-4 text-white placeholder:text-zinc-600 focus:outline-none focus:ring-2 focus:ring-indigo-500/40 focus:border-indigo-500/50 transition-all"
                  required
                />
              </div>
            </div>

            <button
              type="submit"
              class="w-full bg-indigo-600 hover:bg-indigo-500 text-white font-bold py-4 rounded-xl shadow-lg shadow-indigo-600/20 active:scale-[0.98] transition-all flex items-center justify-center gap-2"
            >
              <span>Sign In</span>
              <.icon name="hero-arrow-right" class="size-5" />
            </button>
          </form>

          <div class="mt-8">
            <div class="relative py-4">
              <div class="absolute inset-0 flex items-center">
                <div class="w-full border-t border-zinc-800"></div>
              </div>
              <div class="relative flex justify-center text-xs uppercase tracking-widest font-bold">
                <span class="bg-zinc-900 px-4 text-zinc-500">Or continue with</span>
              </div>
            </div>

            <div id="passkey-container" phx-hook="Passkey" class="mt-4">
              <button
                type="button"
                phx-click="start-passkey-login"
                class="w-full bg-zinc-800/50 hover:bg-zinc-800 text-zinc-300 border border-zinc-700/50 py-3 rounded-xl font-semibold flex items-center justify-center gap-3 transition-colors"
              >
                <.icon name="hero-finger-print" class="size-5 text-indigo-400" /> Sign in with Passkey
              </button>

              <form id="passkey-form" method="post" action="/session" style="display:none;">
                <input type="hidden" name="_csrf_token" value={Plug.CSRFProtection.get_csrf_token()} />
                <input type="hidden" name="passkey_id" value={@passkey_id} />
              </form>
            </div>
          </div>

          <%!-- Demo Credentials --%>
          <div class="mt-10 p-5 rounded-2xl bg-indigo-500/5 border border-indigo-500/10">
            <div class="flex items-center gap-2 mb-3">
              <.icon name="hero-information-circle" class="size-4 text-indigo-400" />
              <span class="text-xs font-bold text-indigo-400 uppercase tracking-widest">
                Demo access
              </span>
            </div>
            <div class="grid grid-cols-1 gap-1 text-[13px] text-zinc-500">
              <p>Email: <span class="text-zinc-300 font-mono">admin@acme.com</span></p>
              <p>Password: <span class="text-zinc-300 font-mono">password123</span></p>
            </div>
          </div>
        </div>

        <p class="mt-8 text-center text-zinc-500 text-xs font-medium">
          &copy; 2026 HelpdeskEx. Built for performance and security.
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
