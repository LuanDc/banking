defmodule Ledger.Repo.Migrations.CreateTrialBalanceView do
  use Ecto.Migration

  # A view over account_balances rather than another projection: the proof of double entry
  # (README, section 4.1) needs no copy of the data to keep in sync.
  def up do
    execute """
    CREATE VIEW trial_balance AS
    SELECT COALESCE(SUM(debit_total), 0)::bigint AS debit_total,
           COALESCE(SUM(credit_total), 0)::bigint AS credit_total
    FROM account_balances
    """
  end

  def down do
    execute "DROP VIEW trial_balance"
  end
end
