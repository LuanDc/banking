defmodule Accounts.Events.CustomerAccountUnblocked do
  @moduledoc """
  A customer account was unblocked: debits are allowed again.
  """

  @derive Jason.Encoder
  defstruct [:account_id]
end
