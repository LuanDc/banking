defmodule Accounts.Commands.ReleaseBalance do
  @moduledoc """
  Intent to give a reservation back to the available balance, compensating a transfer the
  Ledger rejected.
  """

  use Accounts.Command, fields: [:account_id, :correlation_id]

  validates :account_id, presence: true
  validates :correlation_id, presence: true
end
