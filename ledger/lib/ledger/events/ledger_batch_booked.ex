defmodule Ledger.Events.LedgerBatchBooked do
  @moduledoc """
  A batch of ledger entries was booked. Booked entries are immutable.
  """

  defstruct [:batch_id, :correlation_id, :entries]
end
