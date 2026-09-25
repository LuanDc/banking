defmodule Ledger.Repo.Migrations.CreateLedgerAccounts do
  use Ecto.Migration

  def change do
    create table(:ledger_accounts, primary_key: false) do
      add :account_id, :text, primary_key: true
      add :status, :text, null: false
      add :opened_at, :utc_datetime_usec, null: false
      add :closed_at, :utc_datetime_usec
    end

    create constraint(:ledger_accounts, :status_must_be_known,
             check: "status IN ('open', 'closed')"
           )
  end
end
