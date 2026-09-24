defmodule Ledger.Accounts.CustomerAccount do
  @moduledoc """
  Aggregate guarding a customer account's lifecycle, modeled as an FSM.
  """

  alias Ledger.Accounts.Commands.ActivateCustomerAccount
  alias Ledger.Accounts.Commands.OpenCustomerAccount
  alias Ledger.Accounts.Events.CustomerAccountActivated
  alias Ledger.Accounts.Events.CustomerAccountOpened

  defstruct [:account_id, :status]

  def execute(%__MODULE__{status: nil}, %OpenCustomerAccount{} = command) do
    %CustomerAccountOpened{account_id: command.account_id, customer_id: command.customer_id}
  end

  def execute(%__MODULE__{}, %OpenCustomerAccount{}), do: {:error, :account_already_exists}

  def execute(%__MODULE__{status: :pending_kyc}, %ActivateCustomerAccount{} = command) do
    %CustomerAccountActivated{account_id: command.account_id}
  end

  def execute(%__MODULE__{}, %ActivateCustomerAccount{}), do: {:error, :invalid_transition}

  def apply(%__MODULE__{} = account, %CustomerAccountOpened{} = event) do
    %__MODULE__{account | account_id: event.account_id, status: :pending_kyc}
  end

  def apply(%__MODULE__{} = account, %CustomerAccountActivated{}) do
    %__MODULE__{account | status: :active}
  end
end
