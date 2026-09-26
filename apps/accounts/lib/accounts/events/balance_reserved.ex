defmodule Accounts.Events.BalanceReserved do
  @moduledoc """
  An amount of the available balance was held for an outbound transfer. Integration event:
  the Ledger books the transfer from it.
  """

  @derive Jason.Encoder
  defstruct [:account_id, :amount, :correlation_id, :to_account_id]
end
