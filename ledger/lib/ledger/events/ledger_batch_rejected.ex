defmodule Ledger.Events.LedgerBatchRejected do
  @moduledoc """
  A batch was rejected and nothing was booked. Triggers the compensation that releases the
  reservation in Account Management.
  """

  defstruct [:batch_id, :correlation_id, :reason]
end
