defmodule Accounts.Handlers.LedgerRouterIntegrationTest do
  # Smoke test: the policy's commands reach the aggregate through Accounts.App. Which commands
  # each event causes is covered by the pure commands_for/1 tests.
  use ExUnit.Case, async: false

  @moduletag :integration

  alias Accounts.Aggregates.CustomerAccount
  alias Accounts.App
  alias Accounts.Commands.ActivateCustomerAccount
  alias Accounts.Commands.OpenCustomerAccount
  alias Accounts.Events.BalanceReserved
  alias Accounts.Handlers.LedgerRouter
  alias Commanded.Aggregates.Aggregate

  test "dispatches the credit authorization to the destination account" do
    # The event store has no sandbox: fresh ids keep these streams apart from other runs.
    destination = Ecto.UUID.generate()
    :ok = App.dispatch(%OpenCustomerAccount{account_id: destination, customer_id: "cus-1"})
    :ok = App.dispatch(%ActivateCustomerAccount{account_id: destination})

    event = %BalanceReserved{
      account_id: Ecto.UUID.generate(),
      amount: 400,
      correlation_id: Ecto.UUID.generate(),
      to_account_id: destination
    }

    assert :ok = LedgerRouter.handle(event, %{})

    state = Aggregate.aggregate_state(App, CustomerAccount, "customer-account-" <> destination)
    assert state.pending_credits == %{event.correlation_id => 400}
  end
end
