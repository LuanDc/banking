defmodule Accounts.Repo.Migrations.RenameCorrelationIdToTransferId do
  use Ecto.Migration

  # A reservation and a credit belong to a transfer, identified by its transfer_id (README, D17).
  def change do
    rename table(:reservations), :correlation_id, to: :transfer_id
    rename table(:credits), :correlation_id, to: :transfer_id

    rename index(:reservations, [:account_id, :correlation_id]),
      to: "reservations_account_id_transfer_id_index"

    rename index(:credits, [:account_id, :correlation_id]),
      to: "credits_account_id_transfer_id_index"
  end
end
