defmodule Accounts.Events.CreditAuthorized do
  @moduledoc """
  The destination account may receive the amount: the transfer can be booked.
  """

  defstruct [:account_id, :amount, :correlation_id]
end
