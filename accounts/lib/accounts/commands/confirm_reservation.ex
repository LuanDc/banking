defmodule Accounts.Commands.ConfirmReservation do
  @moduledoc """
  Intent to settle a reservation once the Ledger booked its transfer.
  """

  defstruct [:account_id, :correlation_id]
end
