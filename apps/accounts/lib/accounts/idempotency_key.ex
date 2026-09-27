defmodule Accounts.IdempotencyKey do
  @moduledoc """
  A client's `Idempotency-Key`, and the transfer it names (README, D17).
  """

  use Ecto.Schema

  @primary_key false
  schema "idempotency_keys" do
    field :scope, :string, primary_key: true
    field :key, :string, primary_key: true
    field :transfer_id, :string
    field :fingerprint, :string
    field :inserted_at, :utc_datetime_usec
  end
end
