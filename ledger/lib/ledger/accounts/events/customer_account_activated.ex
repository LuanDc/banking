defmodule Ledger.Accounts.Events.CustomerAccountActivated do
  @moduledoc """
  A customer account was activated and can now transact.
  """

  defstruct [:account_id]
end
