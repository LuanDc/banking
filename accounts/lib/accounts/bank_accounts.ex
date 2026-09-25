defmodule Accounts.BankAccounts do
  @moduledoc """
  The bank's own accounts in the Ledger's chart of accounts, opened directly in the Ledger
  (README, D5). They are not customer accounts: no `CustomerAccount` stands behind them, so no
  command is ever dispatched to one here.
  """

  @pix_settlement "pix-settlement"

  @doc "The PIX settlement account, debited by every inbound PIX (README, D2)."
  def pix_settlement, do: @pix_settlement

  def bank_account?(account_id), do: account_id in [@pix_settlement]
end
