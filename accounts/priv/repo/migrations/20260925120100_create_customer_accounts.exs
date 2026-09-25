defmodule Accounts.Repo.Migrations.CreateCustomerAccounts do
  use Ecto.Migration

  def change do
    create table(:customer_accounts, primary_key: false) do
      add :account_id, :text, primary_key: true
      add :customer_id, :text, null: false
      add :status, :text, null: false
      add :status_reason, :text
      add :available_balance, :bigint, null: false, default: 0
      add :opened_at, :utc_datetime_usec, null: false
      add :closed_at, :utc_datetime_usec
      add :updated_at, :utc_datetime_usec, null: false
    end

    create index(:customer_accounts, [:customer_id])

    create constraint(:customer_accounts, :status_must_be_known,
             check: "status IN ('pending_kyc', 'active', 'blocked', 'frozen', 'closed')"
           )

    create table(:customer_account_status_changes) do
      add :account_id, references(:customer_accounts, column: :account_id, type: :text),
        null: false

      add :event, :text, null: false
      add :status, :text, null: false
      add :reason, :text
      add :occurred_at, :utc_datetime_usec, null: false
    end

    create index(:customer_account_status_changes, [:account_id])
  end
end
