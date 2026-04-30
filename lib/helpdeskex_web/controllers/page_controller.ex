defmodule HelpdeskexWeb.PageController do
  use HelpdeskexWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
