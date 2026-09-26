defmodule Accounts.Events.CustomerAccountFrozen do
  @moduledoc """
  A customer account was frozen: neither debits nor credits are allowed.
  """

  @derive Jason.Encoder
  defstruct [:account_id, :reason]
end
