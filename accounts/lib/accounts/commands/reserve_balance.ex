defmodule Accounts.Commands.ReserveBalance do
  @moduledoc """
  Intent to hold an amount, in cents, of the available balance for an outbound transfer.
  """

  defstruct [:account_id, :amount, :correlation_id]
end
