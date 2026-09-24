defmodule Accounts.Commands.AuthorizeCredit do
  @moduledoc """
  Asks the destination account whether it may receive an amount, in cents, before the Ledger
  books a transfer into it.
  """

  defstruct [:account_id, :amount, :correlation_id]
end
