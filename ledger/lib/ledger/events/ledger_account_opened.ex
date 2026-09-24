defmodule Ledger.Events.LedgerAccountOpened do
  @moduledoc """
  An account was opened in the chart of accounts.
  """

  defstruct [:account_id]
end
