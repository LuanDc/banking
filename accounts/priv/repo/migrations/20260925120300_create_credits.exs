defmodule Accounts.Repo.Migrations.CreateCredits do
  use Ecto.Migration

  # No foreign key to customer_accounts: another projector owns that table, and each read
  # model must be rebuildable on its own.
  def change do
    create table(:credits) do
      add :account_id, :text, null: false
      add :correlation_id, :text, null: false
      add :amount, :bigint, null: false
      add :status, :text, null: false
      add :reason, :text
      # Null for a credit posted with no authorization, such as a PIX settlement (D2).
      add :authorized_at, :utc_datetime_usec
      add :settled_at, :utc_datetime_usec
    end

    create unique_index(:credits, [:account_id, :correlation_id])

    # Authorized credits still on their way are what block a closure (D8).
    create index(:credits, [:account_id],
             where: "status = 'authorized'",
             name: :pending_credits
           )

    create constraint(:credits, :status_must_be_known,
             check: "status IN ('authorized', 'posted', 'cancelled', 'rejected')"
           )
  end
end
