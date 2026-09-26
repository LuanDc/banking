defmodule Accounts.Commands.CloseCustomerAccount do
  @moduledoc """
  Intent to close a customer account for good.
  """

  use Accounts.Command, fields: [:account_id]

  validates :account_id, presence: true
end
