defmodule Accounts.Commands.OpenCustomerAccount do
  @moduledoc """
  Intent to open a new customer account, which starts its life in `PENDING_KYC`.
  """

  defstruct [:account_id, :customer_id]

  use ExConstructor

  @doc "Gives the account a new id: the server names accounts, not the client."
  def generate_uuid(%__MODULE__{} = command), do: %{command | account_id: Ecto.UUID.generate()}
end
