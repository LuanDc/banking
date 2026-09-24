defmodule Accounts.Events.CustomerAccountUnblocked do
  @moduledoc """
  A customer account was unblocked: debits are allowed again.
  """

  defstruct [:account_id]
end
