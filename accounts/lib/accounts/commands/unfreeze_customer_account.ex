defmodule Accounts.Commands.UnfreezeCustomerAccount do
  @moduledoc """
  Intent to lift a freeze, allowing the account to send and receive money again.
  """

  defstruct [:account_id]
end
