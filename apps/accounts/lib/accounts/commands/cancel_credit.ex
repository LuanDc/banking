defmodule Accounts.Commands.CancelCredit do
  @moduledoc """
  Drops an authorized credit that will never arrive, because the Ledger rejected its batch.
  """

  use Accounts.Command, fields: [:account_id, :correlation_id]

  validates :account_id, presence: true
  validates :correlation_id, presence: true
end
