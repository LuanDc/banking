defmodule Ledger.Projections.AccountBalance do
  @moduledoc """
  Read model of the ledger balance of each account, the source of truth for money (README, D2).

  `balance` is a column Postgres computes as `credit_total - debit_total`.
  """

  use Ecto.Schema

  @primary_key {:account_id, :string, autogenerate: false}

  schema "account_balances" do
    field :debit_total, :integer
    field :credit_total, :integer
    field :balance, :integer, read_after_writes: true
    field :updated_at, :utc_datetime_usec
  end
end
