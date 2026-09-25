defmodule Ledger.Events.LedgerAccountOpened do
  @moduledoc """
  An account was opened in the chart of accounts.
  """

  @derive Jason.Encoder
  defstruct [:account_id]
end
