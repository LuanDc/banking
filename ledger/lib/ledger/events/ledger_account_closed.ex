defmodule Ledger.Events.LedgerAccountClosed do
  @moduledoc """
  An account was closed in the chart of accounts. Closing is terminal.
  """

  @derive Jason.Encoder
  defstruct [:account_id]
end
