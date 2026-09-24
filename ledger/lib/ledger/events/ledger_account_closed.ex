defmodule Ledger.Events.LedgerAccountClosed do
  @moduledoc """
  An account was closed in the chart of accounts. Closing is terminal.
  """

  defstruct [:account_id]
end
