defmodule Accounts.Repo.Migrations.CreateReservations do
  use Ecto.Migration

  # No foreign key to customer_accounts: another projector owns that table, and each read
  # model must be rebuildable on its own.
  def change do
    create table(:reservations) do
      add :account_id, :text, null: false
      add :correlation_id, :text, null: false
      add :amount, :bigint, null: false
      add :status, :text, null: false
      add :reason, :text
      add :reserved_at, :utc_datetime_usec, null: false
      add :settled_at, :utc_datetime_usec
    end

    create unique_index(:reservations, [:account_id, :correlation_id])

    # Open reservations are the ones queried, and one left open too long is an alert (D6).
    create index(:reservations, [:account_id], where: "status = 'open'", name: :open_reservations)

    create constraint(:reservations, :status_must_be_known,
             check: "status IN ('open', 'confirmed', 'released', 'rejected')"
           )
  end
end
