defmodule Ledger.Projections.StatementEntry do
  @moduledoc """
  Read model of every booked entry, the statement of each account (README, section 7).
  """

  use Ecto.Schema

  schema "ledger_entries" do
    field :batch_id, :string
    field :transfer_id, :string
    field :position, :integer
    field :account_id, :string
    field :type, Ecto.Enum, values: [:debit, :credit]
    field :amount, :integer
    field :booked_at, :utc_datetime_usec
  end
end
