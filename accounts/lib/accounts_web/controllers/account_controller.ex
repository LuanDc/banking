defmodule AccountsWeb.AccountController do
  use AccountsWeb, :controller

  alias Accounts.CustomerAccounts

  action_fallback AccountsWeb.FallbackController

  def show(conn, %{"account_id" => account_id}) do
    with {:ok, account} <- CustomerAccounts.get_customer_account(account_id) do
      render(conn, :show, account: account)
    end
  end
end
