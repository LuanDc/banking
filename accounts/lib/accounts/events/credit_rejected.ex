defmodule Accounts.Events.CreditRejected do
  @moduledoc """
  The destination account may not receive the amount: the transfer is not booked and the source
  reservation is released.
  """

  defstruct [:account_id, :amount, :correlation_id, :reason]
end
