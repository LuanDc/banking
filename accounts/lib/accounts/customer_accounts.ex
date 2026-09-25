defmodule Accounts.CustomerAccounts do
  @moduledoc """
  Entry point of the customer accounts context, for the API.

  Commands are built here and dispatched to the `CustomerAccount` aggregate. Queries read the
  read models (README, section 7 and D11), which are eventually consistent: a query right after a
  command may not see it yet.
  """

  alias Accounts.App
  alias Accounts.Commands.ActivateCustomerAccount
  alias Accounts.Commands.BlockCustomerAccount
  alias Accounts.Commands.CloseCustomerAccount
  alias Accounts.Commands.FreezeCustomerAccount
  alias Accounts.Commands.OpenCustomerAccount
  alias Accounts.Commands.UnblockCustomerAccount
  alias Accounts.Commands.UnfreezeCustomerAccount
  alias Accounts.Projections.CustomerAccount
  alias Accounts.Repo

  @doc "Opens an account for `params[\"customer_id\"]`, under a new id. It starts pending KYC."
  def open_customer_account(params) do
    command =
      params
      |> OpenCustomerAccount.new()
      |> OpenCustomerAccount.generate_uuid()

    with :ok <- App.dispatch(command) do
      {:ok, Map.take(command, [:account_id, :customer_id]) |> Map.put(:status, :pending_kyc)}
    end
  end

  @doc "Activates an account pending KYC."
  def activate_customer_account(params) do
    params
    |> ActivateCustomerAccount.new()
    |> App.dispatch()
  end

  @doc "Blocks an active account's outbound money, for `params[\"reason\"]`."
  def block_customer_account(params) do
    params
    |> BlockCustomerAccount.new()
    |> App.dispatch()
  end

  @doc "Unblocks a blocked account."
  def unblock_customer_account(params) do
    params
    |> UnblockCustomerAccount.new()
    |> App.dispatch()
  end

  @doc "Freezes an active account, for `params[\"reason\"]`."
  def freeze_customer_account(params) do
    params
    |> FreezeCustomerAccount.new()
    |> App.dispatch()
  end

  @doc "Unfreezes a frozen account."
  def unfreeze_customer_account(params) do
    params
    |> UnfreezeCustomerAccount.new()
    |> App.dispatch()
  end

  @doc "Closes an empty account (README, D8)."
  def close_customer_account(params) do
    params
    |> CloseCustomerAccount.new()
    |> App.dispatch()
  end

  def get_customer_account(account_id) do
    case Repo.get(CustomerAccount, account_id) do
      nil -> {:error, :not_found}
      account -> {:ok, account}
    end
  end
end
