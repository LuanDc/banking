defmodule Accounts.Events.CustomerAccountUnfrozen do
  @moduledoc """
  A customer account was unfrozen: debits and credits are allowed again.
  """

  defstruct [:account_id]
end
