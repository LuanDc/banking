defmodule Accounts.CustomerAccount do
  @moduledoc """
  Aggregate guarding a customer account's lifecycle, modeled as an FSM.
  """

  alias Accounts.Commands.ActivateCustomerAccount
  alias Accounts.Commands.BlockCustomerAccount
  alias Accounts.Commands.OpenCustomerAccount
  alias Accounts.Commands.UnblockCustomerAccount
  alias Accounts.Events.CustomerAccountActivated
  alias Accounts.Events.CustomerAccountBlocked
  alias Accounts.Events.CustomerAccountOpened
  alias Accounts.Events.CustomerAccountUnblocked

  defstruct [:account_id, :status]

  # Statuses each command may run from (README, sections 3.1 and 7).
  # The status it leads to is set by the event's apply/2.
  @allowed_from %{
    ActivateCustomerAccount => [:pending_kyc],
    BlockCustomerAccount => [:active],
    UnblockCustomerAccount => [:blocked]
  }

  def execute(%__MODULE__{status: nil}, %OpenCustomerAccount{} = command) do
    %CustomerAccountOpened{account_id: command.account_id, customer_id: command.customer_id}
  end

  def execute(%__MODULE__{}, %OpenCustomerAccount{}), do: {:error, :account_already_exists}

  def execute(%__MODULE__{status: status}, %ActivateCustomerAccount{} = command) do
    with :ok <- guard(status, command) do
      %CustomerAccountActivated{account_id: command.account_id}
    end
  end

  def execute(%__MODULE__{status: status}, %BlockCustomerAccount{} = command) do
    with :ok <- guard(status, command) do
      %CustomerAccountBlocked{account_id: command.account_id, reason: command.reason}
    end
  end

  def execute(%__MODULE__{status: status}, %UnblockCustomerAccount{} = command) do
    with :ok <- guard(status, command) do
      %CustomerAccountUnblocked{account_id: command.account_id}
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

  def apply(%__MODULE__{} = account, %CustomerAccountUnblocked{}) do
    %__MODULE__{account | status: :active}
  end

  defp guard(status, %command{}) do
    if status in Map.fetch!(@allowed_from, command), do: :ok, else: {:error, :invalid_transition}
  end
end
