defmodule Accounts.Commands.ActivateCustomerAccount do
  @moduledoc """
  Intent to activate a customer account once KYC is approved.
  """

  use Accounts.Command, fields: [:account_id]

  validates :account_id, presence: true
end
