defmodule Accounts.Commands.CancelCredit do
  @moduledoc """
  Drops an authorized credit that will never arrive, because the Ledger rejected its batch.
  """

  use Accounts.Command, fields: [:account_id, :transfer_id]

  validates :account_id, presence: true
  validates :transfer_id, presence: true
end
