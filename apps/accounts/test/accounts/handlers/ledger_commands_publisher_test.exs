defmodule Accounts.Handlers.LedgerCommandsPublisherTest do
  use ExUnit.Case, async: true

  import Mox

  alias Accounts.Events.CreditAuthorized
  alias Accounts.Events.CustomerAccountClosed
  alias Accounts.Events.CustomerAccountOpened
  alias Accounts.Handlers.LedgerCommandsPublisher
  alias Accounts.Messaging.PublisherMock
  alias Commanded.Event.FailureContext

  setup :verify_on_exit!

  @metadata %{event_id: "evt-1"}

  test "publishes the ledger command for the event" do
    expect(PublisherMock, :publish, fn message ->
      assert %{type: "OpenLedgerAccount", payload: %{account_id: "acc-1"}} = message
      :ok
    end)

    event = %CustomerAccountOpened{account_id: "acc-1", customer_id: "cus-1"}

    assert :ok = LedgerCommandsPublisher.handle(event, @metadata)
  end

  test "publishes the ledger command when a customer account closes" do
    expect(PublisherMock, :publish, fn message ->
      assert %{type: "CloseLedgerAccount", payload: %{account_id: "acc-1"}} = message
      :ok
    end)

    assert :ok =
             LedgerCommandsPublisher.handle(
               %CustomerAccountClosed{account_id: "acc-1"},
               @metadata
             )
  end

  test "publishes the batch that books an authorized credit" do
    expect(PublisherMock, :publish, fn message ->
      assert %{type: "BookTransactionBatch", payload: %{batch_id: "corr-1"}} = message
      :ok
    end)

    event = %CreditAuthorized{
      account_id: "acc-2",
      amount: 400,
      transfer_id: "corr-1",
      from_account_id: "acc-1"
    }

    assert :ok = LedgerCommandsPublisher.handle(event, @metadata)
  end

  test "retries a failed publish with a growing delay, so the event is never skipped" do
    event = %CustomerAccountClosed{account_id: "acc-1"}

    assert {:retry, first_delay, %FailureContext{context: %{failures: 1}} = failure_context} =
             LedgerCommandsPublisher.error({:error, :closed}, event, %FailureContext{context: %{}})

    assert {:retry, second_delay, %FailureContext{context: %{failures: 2}}} =
             LedgerCommandsPublisher.error({:error, :closed}, event, failure_context)

    assert second_delay > first_delay
  end

  test "caps the retry delay, so a broker back from an outage is not left waiting" do
    event = %CustomerAccountClosed{account_id: "acc-1"}
    failure_context = %FailureContext{context: %{failures: 1_000}}

    assert {:retry, delay, _failure_context} =
             LedgerCommandsPublisher.error({:error, :closed}, event, failure_context)

    assert delay == :timer.minutes(5)
  end
end
