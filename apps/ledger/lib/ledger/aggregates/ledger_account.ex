defmodule Ledger.Aggregates.LedgerAccount do
  @moduledoc """
  Aggregate for an account in the chart of accounts. Its lifecycle is minimal on purpose, OPEN
  and CLOSED: business rules about who may send or receive money live in Accounts (README, D5).

  Its process leaves memory after 5 minutes without a command. The next command rebuilds it
  from its stream.
  """

  @behaviour Commanded.Aggregates.AggregateLifespan

  alias Ledger.Commands.CloseLedgerAccount
  alias Ledger.Commands.OpenLedgerAccount
  alias Ledger.Events.LedgerAccountClosed
  alias Ledger.Events.LedgerAccountOpened

  defstruct [:account_id, :status]

  @idle_timeout :timer.minutes(5)

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

  @impl Commanded.Aggregates.AggregateLifespan
  def after_event(_event), do: @idle_timeout

  @impl Commanded.Aggregates.AggregateLifespan
  def after_command(_command), do: @idle_timeout

  @impl Commanded.Aggregates.AggregateLifespan
  def after_error(_error), do: @idle_timeout
end
