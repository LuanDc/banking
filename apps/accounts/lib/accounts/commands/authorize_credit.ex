defmodule Accounts.Commands.AuthorizeCredit do
  @moduledoc """
  Asks the destination account whether it may receive an amount, in cents, before the Ledger
  books a transfer into it.
  """

  use Accounts.Command, fields: [:account_id, :amount, :transfer_id, :from_account_id]

  validates :account_id, presence: true

  validates :amount,
    by: [
      function: &Accounts.Command.positive_cents?/1,
      message: "must be a positive integer number of cents"
    ]

  validates :transfer_id, presence: true
  validates :from_account_id, presence: true
end
