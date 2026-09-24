defmodule Accounts.Events.CustomerAccountFrozen do
  @moduledoc """
  A customer account was frozen: neither debits nor credits are allowed.
  """

  defstruct [:account_id, :reason]
end
