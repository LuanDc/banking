defmodule Ledger.Projections.LedgerAccount do
  @moduledoc """
  Read model of the chart of accounts: whether each ledger account is open (README, D5).
  """

  use Ecto.Schema

  @primary_key {:account_id, :string, autogenerate: false}

  schema "ledger_accounts" do
    field :status, Ecto.Enum, values: [:open, :closed]
    field :opened_at, :utc_datetime_usec
    field :closed_at, :utc_datetime_usec
  end
end
