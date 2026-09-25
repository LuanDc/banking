defmodule AccountsWeb.AccountController do
  use AccountsWeb, :controller

  alias Accounts.CustomerAccounts

  action_fallback AccountsWeb.FallbackController

  def create(conn, params) do
    with {:ok, account} <- CustomerAccounts.open_customer_account(params) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", ~p"/api/accounts/#{account.account_id}")
      |> render(:created, account: account)
    end
  end

  def index(conn, params) do
    with {:ok, accounts} <- CustomerAccounts.list_customer_accounts(params) do
      render(conn, :index, accounts: accounts)
    end
  end

  def status_history(conn, %{"account_id" => account_id}) do
    with {:ok, changes} <- CustomerAccounts.list_status_changes(account_id) do
      render(conn, :status_history, changes: changes)
    end
  end

  def show(conn, %{"account_id" => account_id}) do
    with {:ok, account} <- CustomerAccounts.get_customer_account(account_id) do
      render(conn, :show, account: account)
    end
  end
end
