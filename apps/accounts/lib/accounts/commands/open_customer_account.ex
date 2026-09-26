defmodule Accounts.Commands.OpenCustomerAccount do
  @moduledoc """
  Intent to open a new customer account, which starts its life in `PENDING_KYC`.
  """

  use Accounts.Command, fields: [:account_id, :customer_id]

  validates :account_id, presence: true
  validates :customer_id, presence: true

  @doc "Gives the account a new id: the server names accounts, not the client."
  def generate_uuid(%__MODULE__{} = command), do: %{command | account_id: Ecto.UUID.generate()}
end
