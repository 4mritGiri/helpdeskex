defmodule HelpdeskexWeb.ResetPasswordLive do
  use HelpdeskexWeb, :live_view

  alias Helpdeskex.Accounts

  @impl true
  def mount(params, _session, socket) do
    token = params["token"]

    case verify_token(token) do
      {:ok, user} ->
        {:ok,
         socket
         |> assign(token: token)
         |> assign(user: user)
         |> assign(form: to_form(%{"password" => "", "password_confirmation" => ""}))}

      {:error, _reason} ->
        {:ok,
         socket
         |> put_flash(:error, "Reset password link is invalid or it has expired.")
         |> redirect(to: "/login")}
    end
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
              <.icon name="hero-shield-check" class="size-5 text-white" />
            </div>
            <div>
              <h1 class="text-lg font-bold text-slate-900 dark:text-white leading-tight">
                Reset password
              </h1>
              <p class="text-xs text-slate-400 dark:text-zinc-500 font-medium mt-0.5">
                Enter your new security key.
              </p>
            </div>
          </div>

          <div class="px-8 py-6">
            <.form for={@form} id="reset_password_form" phx-submit="reset_password" class="space-y-4">
              <div>
                <label class="block text-[11px] font-bold text-slate-500 dark:text-zinc-400 uppercase tracking-wider mb-1.5 ml-0.5">
                  New Password
                </label>
                <div class="relative">
                  <div class="absolute inset-y-0 left-3.5 flex items-center pointer-events-none text-slate-400 dark:text-zinc-500">
                    <.icon name="hero-lock-closed" class="size-4" />
                  </div>
                  <.input
                    field={@form[:password]}
                    type="password"
                    placeholder="••••••••"
                    class="w-full bg-slate-50 dark:bg-zinc-800/60 border border-slate-200 dark:border-zinc-700/60 rounded-xl py-2.5 pl-10 pr-4 text-sm text-slate-900 dark:text-white placeholder:text-slate-400 dark:placeholder:text-zinc-600 focus:outline-none focus:ring-2 focus:ring-indigo-500/30 focus:border-indigo-400 dark:focus:border-indigo-500/50 transition-all"
                    required
                  />
                </div>
              </div>

              <div>
                <label class="block text-[11px] font-bold text-slate-500 dark:text-zinc-400 uppercase tracking-wider mb-1.5 ml-0.5">
                  Confirm Password
                </label>
                <div class="relative">
                  <div class="absolute inset-y-0 left-3.5 flex items-center pointer-events-none text-slate-400 dark:text-zinc-500">
                    <.icon name="hero-lock-closed" class="size-4" />
                  </div>
                  <.input
                    field={@form[:password_confirmation]}
                    type="password"
                    placeholder="••••••••"
                    class="w-full bg-slate-50 dark:bg-zinc-800/60 border border-slate-200 dark:border-zinc-700/60 rounded-xl py-2.5 pl-10 pr-4 text-sm text-slate-900 dark:text-white placeholder:text-slate-400 dark:placeholder:text-zinc-600 focus:outline-none focus:ring-2 focus:ring-indigo-500/30 focus:border-indigo-400 dark:focus:border-indigo-500/50 transition-all"
                    required
                  />
                </div>
              </div>

              <button
                type="submit"
                phx-disable-with="Updating..."
                class="w-full bg-indigo-600 hover:bg-indigo-500 text-white text-sm font-bold py-2.5 rounded-xl shadow-md shadow-indigo-500/20 transition-all active:scale-[0.98] flex items-center justify-center gap-2 mt-1"
              >
                Reset password <.icon name="hero-check" class="size-4" />
              </button>
            </.form>
          </div>
        </div>
      </div>
    </div>
    """
  end

  @impl true
  def handle_event("reset_password", params, socket) do
    %{"password" => password, "password_confirmation" => confirmation} = params

    if password != confirmation do
      {:noreply,
       socket
       |> assign(form: to_form(params))
       |> put_flash(:error, "Passwords do not match.")}
    else
      case Accounts.update_user_password(socket.assigns.user, password) do
        {:ok, _user} ->
          {:noreply,
           socket
           |> put_flash(:info, "Password reset successfully.")
           |> redirect(to: "/login")}

        {:error, _changeset} ->
          {:noreply,
           socket
           |> assign(form: to_form(params))
           |> put_flash(:error, "Oops, something went wrong.")}
      end
    end
  end

  defp verify_token(token) do
    # Token is valid for 24 hours
    max_age = 86_400

    case Phoenix.Token.verify(HelpdeskexWeb.Endpoint, "user_pwd_reset", token, max_age: max_age) do
      {:ok, {user_id, password_hash}} ->
        user = Accounts.get_user!(user_id)

        # Ensure the password hasn't been changed since the token was issued
        if user.password_hash == password_hash do
          {:ok, user}
        else
          {:error, :expired}
        end

      {:error, _} = error ->
        error
    end
  end
end
