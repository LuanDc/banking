defmodule Accounts.Events.CreditPosted do
  @moduledoc """
  A credit booked by the Ledger was added to the available balance.
  """

  @derive Jason.Encoder
  defstruct [:account_id, :amount, :correlation_id]
end
