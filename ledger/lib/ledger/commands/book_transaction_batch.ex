defmodule Ledger.Commands.BookTransactionBatch do
  @moduledoc """
  Intent to book a batch of ledger entries as a single double-entry posting.
  """

  defstruct [:batch_id, :correlation_id, :entries]
end
