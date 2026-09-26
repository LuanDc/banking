defmodule Accounts.Commands.FreezeCustomerAccount do
  @moduledoc """
  Intent to freeze a customer account, stopping both inbound and outbound money.
  """

  use Accounts.Command, fields: [:account_id, :reason]

  validates :account_id, presence: true
  validates :reason, presence: true
end
