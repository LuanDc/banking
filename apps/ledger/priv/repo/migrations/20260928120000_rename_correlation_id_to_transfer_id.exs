defmodule Ledger.Repo.Migrations.RenameCorrelationIdToTransferId do
  use Ecto.Migration

  # An entry's batch settles a transfer, identified by its transfer_id (README, D17).
  def change do
    rename table(:ledger_entries), :correlation_id, to: :transfer_id
  end
end
