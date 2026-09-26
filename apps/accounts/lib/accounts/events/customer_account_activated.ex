defmodule Accounts.Events.CustomerAccountActivated do
  @moduledoc """
  A customer account was activated and can now transact.
  """

  @derive Jason.Encoder
  defstruct [:account_id]
end
