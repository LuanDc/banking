defmodule Accounts.Events.BalanceReservationRejected do
  @moduledoc """
  A reservation was refused and nothing was held, e.g. for lack of available balance.
  """

  defstruct [:account_id, :amount, :correlation_id, :reason]
end
