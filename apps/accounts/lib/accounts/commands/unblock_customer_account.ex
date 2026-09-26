defmodule Accounts.Commands.UnblockCustomerAccount do
  @moduledoc """
  Intent to lift a block, allowing the account to send money again.
  """

  use Accounts.Command, fields: [:account_id]

  validates :account_id, presence: true
end
