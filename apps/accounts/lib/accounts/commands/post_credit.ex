defmodule Accounts.Commands.PostCredit do
  @moduledoc """
  Tells the account that the Ledger booked a credit into it, so the amount, in cents, becomes
  available (README, D2).
  """

  use Accounts.Command, fields: [:account_id, :amount, :correlation_id]

  validates :account_id, presence: true

  validates :amount,
    by: [
      function: &Accounts.Command.positive_cents?/1,
      message: "must be a positive integer number of cents"
    ]

  validates :correlation_id, presence: true
end
