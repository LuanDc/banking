defmodule Ledger.Repo.Migrations.CreateLedgerEntries do
  use Ecto.Migration

  def change do
    create table(:ledger_entries) do
      add :batch_id, :text, null: false
      add :correlation_id, :text, null: false
      add :position, :integer, null: false
      add :account_id, :text, null: false
      add :type, :text, null: false
      add :amount, :bigint, null: false
      add :booked_at, :utc_datetime_usec, null: false
    end

    create unique_index(:ledger_entries, [:batch_id, :position])
    create index(:ledger_entries, [:account_id, :booked_at])

    create constraint(:ledger_entries, :type_must_be_known, check: "type IN ('debit', 'credit')")
    create constraint(:ledger_entries, :amount_must_be_positive, check: "amount > 0")
  end
end
