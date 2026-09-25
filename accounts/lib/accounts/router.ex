defmodule Accounts.Router do
  @moduledoc """
  Routes every command to the CustomerAccount aggregate that owns it.
  """

  use Commanded.Commands.Router

  alias Accounts.Commands
  alias Accounts.CustomerAccount

  identify(CustomerAccount, by: :account_id, prefix: "customer-account-")

  dispatch(
    [
      Commands.OpenCustomerAccount,
      Commands.ActivateCustomerAccount,
      Commands.BlockCustomerAccount,
      Commands.UnblockCustomerAccount,
      Commands.FreezeCustomerAccount,
      Commands.UnfreezeCustomerAccount,
      Commands.CloseCustomerAccount,
      Commands.ReserveBalance,
      Commands.ConfirmReservation,
      Commands.ReleaseBalance,
      Commands.AuthorizeCredit,
      Commands.PostCredit,
      Commands.CancelCredit
    ],
    to: CustomerAccount
  )
end
