defmodule Ledger.Repo.Migrations.CreateAccountBalances do
  use Ecto.Migration

  # Both totals are kept, so no sign convention per kind of account is needed: the balance is
  # credits minus debits, negative for a settlement account and positive for a customer's.
  def change do
    create table(:account_balances, primary_key: false) do
      add :account_id, :text, primary_key: true
      add :debit_total, :bigint, null: false, default: 0
      add :credit_total, :bigint, null: false, default: 0
      add :balance, :bigint, generated: "ALWAYS AS (credit_total - debit_total) STORED"
      add :updated_at, :utc_datetime_usec, null: false
    end
  end
end
