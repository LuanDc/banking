defmodule Accounts.Commands.ActivateCustomerAccount do
  @moduledoc """
  Intent to activate a customer account once KYC is approved.
  """

  defstruct [:account_id]

  use ExConstructor
end
