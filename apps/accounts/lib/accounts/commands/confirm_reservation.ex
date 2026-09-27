defmodule Accounts.Commands.ConfirmReservation do
  @moduledoc """
  Intent to settle a reservation once the Ledger booked its transfer.
  """

  use Accounts.Command, fields: [:account_id, :transfer_id]

  validates :account_id, presence: true
  validates :transfer_id, presence: true
end
