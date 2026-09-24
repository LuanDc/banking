defmodule Accounts.Commands.BlockCustomerAccount do
  @moduledoc """
  Intent to block a customer account's outbound money, keeping inbound credits allowed.
  """

  defstruct [:account_id, :reason]
end
