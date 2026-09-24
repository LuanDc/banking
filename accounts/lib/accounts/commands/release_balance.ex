defmodule Accounts.Commands.ReleaseBalance do
  @moduledoc """
  Intent to give a reservation back to the available balance, compensating a transfer the
  Ledger rejected.
  """

  defstruct [:account_id, :correlation_id]
end
