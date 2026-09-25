defmodule Accounts.Commands.UnblockCustomerAccount do
  @moduledoc """
  Intent to lift a block, allowing the account to send money again.
  """

  defstruct [:account_id]

  use ExConstructor
end
