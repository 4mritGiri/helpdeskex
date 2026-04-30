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
    <div class="min-h-screen flex items-center justify-center relative overflow-hidden bg-[#050505] font-sans selection:bg-indigo-500/30">
      <%!-- Immersive Background --%>
      <div class="absolute inset-0 z-0">
        <img
          src="/images/login_bg.png"
          class="w-full h-full object-cover opacity-40 scale-110"
          style="filter: blur(60px); mix-blend-mode: screen;"
        />
        <div class="absolute inset-0 bg-gradient-to-b from-black via-transparent to-black/80"></div>
      </div>

      <div class="relative z-10 w-full max-w-[460px] px-6 py-12">
        <%!-- Header Section --%>
        <div class="flex flex-col items-center mb-12 animate-in fade-in slide-in-from-bottom-4 duration-1000">
          <div class="group relative mb-8">
            <div class="absolute -inset-4 bg-indigo-500/20 rounded-full blur-2xl group-hover:bg-indigo-500/30 transition-all duration-700">
            </div>
            <div class="relative size-14 rounded-2xl bg-white/[0.03] border border-white/10 flex items-center justify-center shadow-inner overflow-hidden">
              <div class="absolute inset-0 bg-gradient-to-tr from-indigo-500/10 to-transparent"></div>
              <span class="text-xl font-black text-white tracking-tighter leading-none">
                H<span class="text-indigo-500">X</span>
              </span>
            </div>
          </div>
          <h1 class="text-4xl font-bold text-white tracking-tight leading-tight mb-3">
            Welcome back
          </h1>
          <p class="text-zinc-500 text-sm font-medium tracking-wide">
            Enter your credentials to access your workspace
          </p>
        </div>

        <%!-- Main Form Card --%>
        <div class="backdrop-blur-[32px] bg-white/[0.02] border border-white/10 rounded-[40px] p-1 pt-1 shadow-2xl animate-in zoom-in-95 duration-700">
          <div class="bg-zinc-950/40 rounded-[39px] p-8 md:p-10">
            <%= if flash = @flash["error"] do %>
              <div class="mb-8 p-4 rounded-2xl bg-red-500/5 border border-red-500/10 flex items-center gap-3 animate-in fade-in zoom-in-95">
                <div class="size-2 rounded-full bg-red-500 shadow-[0_0_10px_rgba(239,68,68,0.5)]">
                </div>
                <p class="text-sm font-semibold text-red-400/90">{flash}</p>
              </div>
            <% end %>

            <form method="post" action="/session" class="space-y-8">
              <input type="hidden" name="_csrf_token" value={Plug.CSRFProtection.get_csrf_token()} />

              <div class="space-y-3">
                <div class="flex justify-between items-end px-1">
                  <label class="text-[10px] font-black text-zinc-500 uppercase tracking-[0.2em]">
                    User Identity
                  </label>
                </div>
                <div class="relative">
                  <div class="absolute inset-y-0 left-5 flex items-center pointer-events-none text-zinc-600 transition-colors duration-300">
                    <.icon name="hero-envelope" class="size-5" />
                  </div>
                  <input
                    id="email"
                    type="email"
                    name="email"
                    placeholder="name@company.com"
                    autocomplete="email"
                    class="w-full bg-white/[0.03] border border-white/5 rounded-2xl py-4 pl-14 pr-5 text-[15px] text-white placeholder:text-zinc-700 focus:outline-none focus:bg-white/[0.06] focus:border-indigo-500/30 transition-all duration-300 shadow-inner"
                    required
                  />
                </div>
              </div>

              <div class="space-y-3">
                <div class="flex justify-between items-end px-1">
                  <label class="text-[10px] font-black text-zinc-500 uppercase tracking-[0.2em]">
                    Security Key
                  </label>
                  <a
                    href="#"
                    class="text-[10px] font-bold text-indigo-400 hover:text-indigo-300 uppercase tracking-widest transition-colors"
                  >
                    Recover?
                  </a>
                </div>
                <div class="relative">
                  <div class="absolute inset-y-0 left-5 flex items-center pointer-events-none text-zinc-600 transition-colors duration-300">
                    <.icon name="hero-lock-closed" class="size-5" />
                  </div>
                  <input
                    id="password"
                    type="password"
                    name="password"
                    placeholder="••••••••••••"
                    autocomplete="current-password"
                    class="w-full bg-white/[0.03] border border-white/5 rounded-2xl py-4 pl-14 pr-5 text-[15px] text-white placeholder:text-zinc-700 focus:outline-none focus:bg-white/[0.06] focus:border-indigo-500/30 transition-all duration-300 shadow-inner"
                    required
                  />
                </div>
              </div>

              <button
                type="submit"
                class="group relative w-full overflow-hidden rounded-2xl bg-indigo-600 p-4 transition-all duration-500 hover:bg-indigo-500 active:scale-[0.98] shadow-[0_20px_50px_rgba(79,70,229,0.2)]"
              >
                <div class="absolute inset-0 bg-gradient-to-r from-indigo-400/20 to-transparent translate-x-[-100%] group-hover:translate-x-[100%] transition-transform duration-1000">
                </div>
                <span class="relative flex items-center justify-center gap-3 text-sm font-extrabold text-white uppercase tracking-[0.15em]">
                  Authenticate
                  <.icon
                    name="hero-arrow-right"
                    class="size-4 transition-transform group-hover:translate-x-1"
                  />
                </span>
              </button>
            </form>

            <div class="mt-10">
              <div class="relative flex items-center justify-center">
                <div class="absolute w-full border-t border-white/[0.03]"></div>
                <span class="relative px-6 bg-[#0c0c0e] text-[9px] font-black text-zinc-600 uppercase tracking-[0.3em]">
                  Alternate Login
                </span>
              </div>

              <div id="passkey-container" phx-hook="Passkey" class="mt-8">
                <button
                  type="button"
                  phx-click="start-passkey-login"
                  class="w-full bg-white/[0.02] hover:bg-white/[0.05] text-zinc-400 border border-white/5 py-4 rounded-2xl font-bold text-xs flex items-center justify-center gap-3 transition-all duration-300"
                >
                  <.icon name="hero-finger-print" class="size-5 text-indigo-500/70" />
                  Continue with Biometrics
                </button>

                <form id="passkey-form" method="post" action="/session" style="display:none;">
                  <input
                    type="hidden"
                    name="_csrf_token"
                    value={Plug.CSRFProtection.get_csrf_token()}
                  />
                  <input type="hidden" name="passkey_id" value={@passkey_id} />
                </form>
              </div>
            </div>
          </div>
        </div>

        <%!-- Footer Section --%>
        <div class="mt-8 flex flex-col items-center gap-8 animate-in fade-in duration-1000">
          <div class="flex items-center gap-6 px-1">
            <div class="flex flex-col items-center gap-1">
              <span class="text-[9px] font-black text-zinc-600 uppercase tracking-widest">
                Admin Demo
              </span>
              <span class="text-[11px] font-medium text-zinc-400">admin@acme.com / password123</span>
            </div>
          </div>

          <p class="text-zinc-600 text-[10px] font-bold uppercase tracking-[0.2em] opacity-50">
            &copy; 2026 Secured BY HelpdeskEx Core
          </p>
        </div>
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
