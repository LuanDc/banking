defmodule Accounts.Events.CreditAuthorized do
  @moduledoc """
  The destination account may receive the amount: the transfer can be booked.
  """

  @derive Jason.Encoder
  defstruct [:account_id, :amount, :correlation_id]
end
