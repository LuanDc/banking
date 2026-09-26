defmodule Accounts.Commands.UnfreezeCustomerAccount do
  @moduledoc """
  Intent to lift a freeze, allowing the account to send and receive money again.
  """

  use Accounts.Command, fields: [:account_id]

  validates :account_id, presence: true
end
