defmodule Ledger.Commands.BookTransactionBatch do
  @moduledoc """
  Intent to book a batch of ledger entries as a single double-entry posting.

  `accounts_not_open` is not part of the message: the dispatch pipeline fills it in from the open
  ledger accounts (README, D5), so the aggregate stays a pure function of its command.
  """

  defstruct [:batch_id, :transfer_id, :entries, accounts_not_open: []]
end
