defmodule Accounts.Commands.ReserveBalance do
  @moduledoc """
  Intent to hold an amount, in cents, of the available balance for an outbound transfer.
  """

  use Accounts.Command, fields: [:account_id, :amount, :transfer_id, :to_account_id]

  validates :account_id, presence: true

  validates :amount,
    by: [
      function: &Accounts.Command.positive_cents?/1,
      message: "must be a positive integer number of cents"
    ]

  validates :transfer_id, presence: true

  validates :to_account_id,
    presence: true,
    by: [function: &Accounts.Command.other_account?/2, message: "must be another account"]
end
