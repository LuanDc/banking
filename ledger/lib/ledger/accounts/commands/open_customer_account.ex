defmodule Ledger.Accounts.Commands.OpenCustomerAccount do
  @moduledoc """
  Intent to open a new customer account, which starts its life in `PENDING_KYC`.
  """

  defstruct [:account_id, :customer_id]
end
