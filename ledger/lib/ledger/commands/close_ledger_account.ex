defmodule Ledger.Commands.CloseLedgerAccount do
  @moduledoc """
  Intent to close an account in the chart of accounts, so no further entries are booked into it.
  """

  defstruct [:account_id]
end
