defmodule LedgerWeb.LedgerAccountController do
  use LedgerWeb, :controller

  alias Ledger.LedgerAccounts

  action_fallback LedgerWeb.FallbackController

  def show(conn, %{"account_id" => account_id}) do
    with {:ok, account} <- LedgerAccounts.get_ledger_account(account_id) do
      render(conn, :show, account: account)
    end
  end

  def balance(conn, %{"account_id" => account_id}) do
    with {:ok, balance} <- LedgerAccounts.get_balance(account_id) do
      render(conn, :balance, balance: balance)
    end
  end

  def entries(conn, params) do
    with {:ok, page} <- LedgerAccounts.list_entries(params) do
      render(conn, :entries, page: page)
    end
  end

  def trial_balance(conn, _params) do
    render(conn, :trial_balance, trial_balance: LedgerAccounts.get_trial_balance())
  end
end
