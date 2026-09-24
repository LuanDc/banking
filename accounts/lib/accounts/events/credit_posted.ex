defmodule Accounts.Events.CreditPosted do
  @moduledoc """
  A credit booked by the Ledger was added to the available balance.
  """

  defstruct [:account_id, :amount, :correlation_id]
end
