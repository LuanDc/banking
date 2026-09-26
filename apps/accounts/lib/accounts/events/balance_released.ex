defmodule Accounts.Events.BalanceReleased do
  @moduledoc """
  A reservation was released: its amount is available again.
  """

  @derive Jason.Encoder
  defstruct [:account_id, :correlation_id, :amount]
end
