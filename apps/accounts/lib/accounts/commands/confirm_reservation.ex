defmodule Accounts.Commands.ConfirmReservation do
  @moduledoc """
  Intent to settle a reservation once the Ledger booked its transfer.
  """

  use Accounts.Command, fields: [:account_id, :correlation_id]

  validates :account_id, presence: true
  validates :correlation_id, presence: true
end
