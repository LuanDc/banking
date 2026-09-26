# The bank's internal accounts, opened directly in the Ledger (README, D5). Run with
# `mix run priv/repo/seeds.exs`, also part of `mix setup`. Opening is idempotent (D4).
#
#   pix-settlement: the bank's PIX settlement account, debited by every inbound PIX (D2).

alias Ledger.App
alias Ledger.Commands.OpenLedgerAccount

for account_id <- ["pix-settlement"] do
  :ok = App.dispatch(%OpenLedgerAccount{account_id: account_id}, consistency: :strong)
end
