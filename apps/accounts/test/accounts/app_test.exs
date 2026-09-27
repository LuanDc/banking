defmodule Accounts.AppTest do
  # Smoke test of the Commanded wiring: router, event store and serializer. The rules
  # themselves are covered by the pure CustomerAccount tests.
  use ExUnit.Case, async: false

  @moduletag :integration

  alias Accounts.Aggregates.CustomerAccount
  alias Accounts.App
  alias Accounts.Commands.OpenCustomerAccount
  alias Commanded.Registration

  test "dispatches to CustomerAccount, which is rebuilt from its stored events" do
    # The event store has no sandbox: a fresh id keeps this stream apart from other runs.
    command = %OpenCustomerAccount{account_id: Ecto.UUID.generate(), customer_id: "cus-1"}

    assert :ok = App.dispatch(command)
    assert {:error, :account_already_exists} = App.dispatch(command)
  end

  test "keeps an account's process until it has gone 5 minutes without a command" do
    account_id = Ecto.UUID.generate()

    assert :ok = App.dispatch(%OpenCustomerAccount{account_id: account_id, customer_id: "cus-1"})

    pid =
      Registration.whereis_name(App, {App, CustomerAccount, "customer-account-" <> account_id})

    assert :sys.get_state(pid).lifespan_timeout == :timer.minutes(5)
  end
end
