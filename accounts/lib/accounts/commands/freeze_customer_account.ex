defmodule Accounts.Commands.FreezeCustomerAccount do
  @moduledoc """
  Intent to freeze a customer account, stopping both inbound and outbound money.
  """

  defstruct [:account_id, :reason]

  use ExConstructor
end
