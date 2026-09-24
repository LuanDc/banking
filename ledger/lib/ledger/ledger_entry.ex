defmodule Ledger.LedgerEntry do
  @moduledoc """
  One side of a double-entry posting: a debit or a credit of an amount, in cents, to an account.
  """

  defstruct [:account_id, :type, :amount]
end
