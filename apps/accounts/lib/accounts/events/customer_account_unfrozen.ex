defmodule Accounts.Events.CustomerAccountUnfrozen do
  @moduledoc """
  A customer account was unfrozen: debits and credits are allowed again.
  """

  @derive Jason.Encoder
  defstruct [:account_id]
end
