defmodule LedgerWeb.Router do
  use LedgerWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/api", LedgerWeb do
    pipe_through :api

    get "/ledger-accounts/:account_id", LedgerAccountController, :show
    get "/ledger-accounts/:account_id/balance", LedgerAccountController, :balance
    get "/ledger-accounts/:account_id/entries", LedgerAccountController, :entries
    get "/batches/:batch_id", BatchController, :show
    get "/trial-balance", LedgerAccountController, :trial_balance
  end
end
