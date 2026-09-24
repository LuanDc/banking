defmodule Accounts.Commands.PostCredit do
  @moduledoc """
  Tells the account that the Ledger booked a credit into it, so the amount, in cents, becomes
  available (README, D2).
  """

  defstruct [:account_id, :amount, :correlation_id]
end
