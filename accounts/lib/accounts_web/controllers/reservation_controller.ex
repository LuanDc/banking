defmodule AccountsWeb.ReservationController do
  use AccountsWeb, :controller

  alias Accounts.CustomerAccounts

  action_fallback AccountsWeb.FallbackController

  def index(conn, params) do
    with {:ok, page} <- CustomerAccounts.list_reservations(params) do
      render(conn, :index, page: page)
    end
  end
end
