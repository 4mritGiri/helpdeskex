defmodule HelpdeskexWeb.Layouts do
  @moduledoc """
  This module holds layouts and related functionality
  used by your application.
  """
  use HelpdeskexWeb, :html

  # Embed all files in layouts/* within this module.
  # The default root.html.heex file contains the HTML
  # skeleton of your application, namely HTML headers
  # and other static content.
  embed_templates "layouts/*"

  @doc """
  Renders your app layout.

  This function is typically invoked from every template,
  and it often contains your application menu, sidebar,
  or similar.

  ## Examples

      <Layouts.app flash={@flash}>
        <h1>Content</h1>
      </Layouts.app>

  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :theme, :string, default: "light"
  attr :current_view, :string, default: "kanban"
  attr :sidebar_collapsed, :boolean, default: false
  attr :current_user, :any, default: nil
  attr :stats, :map, default: %{open: 0, in_progress: 0, resolved: 0}

  attr :current_scope, :map,
    default: nil,
    doc: "the current [scope](https://hexdocs.pm/phoenix/scopes.html)"

  slot :inner_block, required: true

  def app(assigns) do
    ~H"""
    <div class="app" id="app" data-theme={@theme} phx-hook="Persistence">
      <.sidebar
        current_view={@current_view}
        collapsed={@sidebar_collapsed}
        user={@current_user}
        stats={@stats}
      />

      <div class="main">
        {render_slot(@inner_block)}
      </div>

      <.flash_group flash={@flash} />
    </div>
    """
  end

  attr :current_view, :string, required: true
  attr :collapsed, :boolean, default: false
  attr :user, :any, required: true
  attr :stats, :map, required: true

  def sidebar(assigns) do
    assigns = assign(assigns, :items, HelpdeskexWeb.SidebarConfig.sidebar_items(assigns.user))

    ~H"""
    <div class={["sidebar", @collapsed && "collapsed"]} id="sidebar">
      <div class="sidebar-logo">
        <div class="brand-dot"><svg viewBox="0 0 13 13"><path d="M2 6.5h9M6.5 2v9" /></svg></div>
        <div class="brand-text">
          <div class="name">DeskFlow</div>
          <div class="org">National Bank</div>
        </div>
        <div class="toggle-btn" phx-click="toggle_sidebar">
          <svg viewBox="0 0 12 12"><path d="M8 2L4 6l4 4" /></svg>
        </div>
      </div>

      <div class="nav">
        <%= for item <- @items do %>
          <%= if Map.has_key?(item, :section) do %>
            <div class="nav-section">{item.section}</div>
          <% else %>
            <.sidebar_item
              item={item}
              current_view={@current_view}
              badge={
                cond do
                  item[:badge_count] -> @stats.open + @stats.in_progress + @stats.resolved
                  item[:badge] -> item.badge
                  true -> nil
                end
              }
            />
          <% end %>
        <% end %>
      </div>

      <div class="agent-area">
        <div class="agent-av">{HelpdeskexWeb.DashboardLive.requester_initials(@user)}</div>
        <div class="agent-info">
          <div class="agent-name">{if @user, do: @user.full_name, else: "Agent"}</div>
          <div class="agent-role">System Admin</div>
        </div>
        <.link
          href="/session"
          method="delete"
          class="ml-auto flex items-center justify-center text-slate-400 hover:text-red-500 transition-colors"
          title="Logout"
        >
          <.icon name="hero-arrow-right-start-on-rectangle" class="w-5 h-5 flex-shrink-0" />
        </.link>
      </div>
    </div>
    """
  end

  attr :item, :map, required: true
  attr :current_view, :string, required: true
  attr :badge, :any, default: nil

  def sidebar_item(assigns) do
    ~H"""
    <%= if Map.has_key?(@item, :path) do %>
      <.link
        navigate={@item.path}
        class={["nav-item", @current_view == @item.view && "active"]}
      >
        <.icon name={@item.icon} class="nav-icon" />
        <span class="nav-label">{@item.label}</span>
        <span :if={@badge} class="nav-badge">{@badge}</span>
        <div class="sidebar-tooltip">{@item.label}</div>
      </.link>
    <% else %>
      <div
        class={["nav-item", @current_view == @item.view && "active"]}
        phx-click="switch_view"
        phx-value-view={@item.view}
      >
        <.icon name={@item.icon} class="nav-icon" />
        <span class="nav-label">{@item.label}</span>
        <span :if={@badge} class="nav-badge">{@badge}</span>
        <div class="sidebar-tooltip">{@item.label}</div>
      </div>
    <% end %>
    """
  end

  @doc """
  Shows the flash group with standard titles and content.

  ## Examples

      <.flash_group flash={@flash} />
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :id, :string, default: "flash-group", doc: "the optional id of flash container"

  def flash_group(assigns) do
    ~H"""
    <div
      id={@id}
      aria-live="polite"
      class="fixed top-6 right-0 -translate-x-1/2 z-[9999] flex flex-col items-center gap-3 w-fit"
    >
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />

      <.flash
        id="client-error"
        kind={:error}
        title={gettext("We can't find the internet")}
        phx-disconnected={show(".phx-client-error #client-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#client-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>

      <.flash
        id="server-error"
        kind={:error}
        title={gettext("Something went wrong!")}
        phx-disconnected={show(".phx-server-error #server-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#server-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>
    </div>
    """
  end

  @doc """
  Provides dark vs light theme toggle based on themes defined in app.css.

  See <head> in root.html.heex which applies the theme before page load.
  """
  def theme_toggle(assigns) do
    ~H"""
    <div class="card relative flex flex-row items-center border-2 border-base-300 bg-base-300 rounded-full">
      <div class="absolute w-1/3 h-full rounded-full border-1 border-base-200 bg-base-100 brightness-200 left-0 [[data-theme=light]_&]:left-1/3 [[data-theme=dark]_&]:left-2/3 transition-[left]" />

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="system"
      >
        <.icon name="hero-computer-desktop-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="light"
      >
        <.icon name="hero-sun-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="dark"
      >
        <.icon name="hero-moon-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>
    </div>
    """
  end
end
