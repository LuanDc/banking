defmodule Ledger.Accounts.CustomerAccount do
  @moduledoc """
  Aggregate guarding a customer account's lifecycle, modeled as an FSM.
  """

  alias Ledger.Accounts.Commands.OpenCustomerAccount
  alias Ledger.Accounts.Events.CustomerAccountOpened

  defstruct [:account_id, :status]

  def execute(%__MODULE__{status: nil}, %OpenCustomerAccount{} = command) do
    %CustomerAccountOpened{account_id: command.account_id, customer_id: command.customer_id}
  end

  def execute(%__MODULE__{}, %OpenCustomerAccount{}), do: {:error, :account_already_exists}

  def apply(%__MODULE__{} = account, %CustomerAccountOpened{} = event) do
    %__MODULE__{account | account_id: event.account_id, status: :pending_kyc}
  end
end
