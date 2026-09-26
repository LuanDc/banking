defmodule Accounts.Repo.Migrations.AddToAccountIdToReservations do
  use Ecto.Migration

  # The destination of the transfer the reservation holds money for, so a transfer can be read
  # from its reservation alone (README, D12). Rows projected before it stay null.
  def change do
    alter table(:reservations) do
      add :to_account_id, :text
    end
  end
end
