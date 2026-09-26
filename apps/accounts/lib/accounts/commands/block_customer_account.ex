defmodule Accounts.Commands.BlockCustomerAccount do
  @moduledoc """
  Intent to block a customer account's outbound money, keeping inbound credits allowed.
  """

  use Accounts.Command, fields: [:account_id, :reason]

  validates :account_id, presence: true
  validates :reason, presence: true
end
