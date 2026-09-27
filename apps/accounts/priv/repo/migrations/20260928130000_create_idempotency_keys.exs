defmodule Accounts.Repo.Migrations.CreateIdempotencyKeys do
  use Ecto.Migration

  # The API's edge (README, D17): the transfer a client's Idempotency-Key names, within the scope
  # of the account it was sent for. Not a read model: no projector owns it.
  def change do
    create table(:idempotency_keys, primary_key: false) do
      add :scope, :text, primary_key: true
      add :key, :text, primary_key: true
      add :transfer_id, :text, null: false
      add :fingerprint, :text, null: false
      add :inserted_at, :utc_datetime_usec, null: false
    end
  end
end
