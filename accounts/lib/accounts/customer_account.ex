defmodule Accounts.CustomerAccount do
  @moduledoc """
  Aggregate guarding a customer account's lifecycle, modeled as an FSM.
  """

  alias Accounts.Commands.ActivateCustomerAccount
  alias Accounts.Commands.BlockCustomerAccount
  alias Accounts.Commands.OpenCustomerAccount
  alias Accounts.Events.CustomerAccountActivated
  alias Accounts.Events.CustomerAccountBlocked
  alias Accounts.Events.CustomerAccountOpened
  alias Accounts.StateMachine

  defstruct [:account_id, :status]

  def execute(%__MODULE__{status: nil}, %OpenCustomerAccount{} = command) do
    %CustomerAccountOpened{account_id: command.account_id, customer_id: command.customer_id}
  end

  def execute(%__MODULE__{}, %OpenCustomerAccount{}), do: {:error, :account_already_exists}

  def execute(%__MODULE__{status: status}, %ActivateCustomerAccount{} = command) do
    with :ok <- StateMachine.transition(status, :active) do
      %CustomerAccountActivated{account_id: command.account_id}
    end
  end

  def execute(%__MODULE__{status: status}, %BlockCustomerAccount{} = command) do
    with :ok <- StateMachine.transition(status, :blocked) do
      %CustomerAccountBlocked{account_id: command.account_id, reason: command.reason}
    end
  end

  def apply(%__MODULE__{} = account, %CustomerAccountOpened{} = event) do
    %__MODULE__{account | account_id: event.account_id, status: :pending_kyc}
  end

  def apply(%__MODULE__{} = account, %CustomerAccountActivated{}) do
    %__MODULE__{account | status: :active}
  end

  def apply(%__MODULE__{} = account, %CustomerAccountBlocked{}) do
    %__MODULE__{account | status: :blocked}
  end
end
