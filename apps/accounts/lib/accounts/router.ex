defmodule Accounts.Router do
  @moduledoc """
  Routes every command to the CustomerAccount aggregate that owns it.
  """

  use Commanded.Commands.Router

  alias Accounts.Aggregates.CustomerAccount
  alias Accounts.Commands

  # README, D14: a command that breaks its input rules never reaches the aggregate.
  middleware(Accounts.Middleware.ValidateCommand)

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
