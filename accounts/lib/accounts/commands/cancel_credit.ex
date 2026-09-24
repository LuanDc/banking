defmodule Accounts.Commands.CancelCredit do
  @moduledoc """
  Drops an authorized credit that will never arrive, because the Ledger rejected its batch.
  """

  defstruct [:account_id, :correlation_id]
end
