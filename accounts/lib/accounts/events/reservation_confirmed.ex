defmodule Accounts.Events.ReservationConfirmed do
  @moduledoc """
  A reservation was settled: its amount left the account for good, as booked by the Ledger.
  """

  defstruct [:account_id, :correlation_id, :amount]
end
