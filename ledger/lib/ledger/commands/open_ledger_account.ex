defmodule Ledger.Commands.OpenLedgerAccount do
  @moduledoc """
  Intent to open an account in the chart of accounts, so entries can be booked into it.
  """

  defstruct [:account_id]
end
