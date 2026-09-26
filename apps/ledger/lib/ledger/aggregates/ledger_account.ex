defmodule Ledger.Aggregates.LedgerAccount do
  @moduledoc """
  Aggregate for an account in the chart of accounts. Its lifecycle is minimal on purpose, OPEN
  and CLOSED: business rules about who may send or receive money live in Accounts (README, D5).
  """

  alias Ledger.Commands.CloseLedgerAccount
  alias Ledger.Commands.OpenLedgerAccount
  alias Ledger.Events.LedgerAccountClosed
  alias Ledger.Events.LedgerAccountOpened

  defstruct [:account_id, :status]

  def execute(%__MODULE__{status: nil}, %OpenLedgerAccount{} = command) do
    %LedgerAccountOpened{account_id: command.account_id}
  end

  # README, D4: a redelivered open for an existing account does nothing.
  def execute(%__MODULE__{}, %OpenLedgerAccount{}), do: []

  def execute(%__MODULE__{status: :open}, %CloseLedgerAccount{} = command) do
    %LedgerAccountClosed{account_id: command.account_id}
  end

  def execute(%__MODULE__{status: :closed}, %CloseLedgerAccount{}), do: []

  def execute(%__MODULE__{status: nil}, %CloseLedgerAccount{}), do: {:error, :account_not_found}

  def apply(%__MODULE__{} = account, %LedgerAccountOpened{} = event) do
    %__MODULE__{account | account_id: event.account_id, status: :open}
  end

  def apply(%__MODULE__{} = account, %LedgerAccountClosed{}) do
    %__MODULE__{account | status: :closed}
  end
end
