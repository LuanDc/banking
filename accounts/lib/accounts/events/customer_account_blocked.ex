defmodule Accounts.Events.CustomerAccountBlocked do
  @moduledoc """
  A customer account was blocked: debits are no longer allowed.
  """

  defstruct [:account_id, :reason]
end
