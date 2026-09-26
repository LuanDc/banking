defmodule Ledger.Handlers.LedgerEventsPublisherTest do
  use ExUnit.Case, async: true

  import Mox

  alias Commanded.Event.FailureContext
  alias Ledger.Events.LedgerAccountOpened
  alias Ledger.Events.LedgerBatchBooked
  alias Ledger.Handlers.LedgerEventsPublisher
  alias Ledger.Messaging.PublisherMock

  setup :verify_on_exit!

  @metadata %{event_id: "evt-1"}

  test "publishes a booked batch" do
    expect(PublisherMock, :publish, fn message ->
      assert %{type: "LedgerBatchBooked", payload: %{batch_id: "batch-1"}} = message
      :ok
    end)

    event = %LedgerBatchBooked{batch_id: "batch-1", correlation_id: "corr-1", entries: []}

    assert :ok = LedgerEventsPublisher.handle(event, @metadata)
  end

  test "keeps the events no other context needs to itself" do
    assert :ok =
             LedgerEventsPublisher.handle(%LedgerAccountOpened{account_id: "acc-1"}, @metadata)
  end

  test "retries a failed publish with a growing, capped delay, so the event is never skipped" do
    event = %LedgerBatchBooked{}

    assert {:retry, first_delay, failure_context} =
             LedgerEventsPublisher.error({:error, :closed}, event, %FailureContext{context: %{}})

    assert {:retry, second_delay, _failure_context} =
             LedgerEventsPublisher.error({:error, :closed}, event, failure_context)

    assert second_delay > first_delay

    assert {:retry, capped, _failure_context} =
             LedgerEventsPublisher.error(
               {:error, :closed},
               event,
               %FailureContext{context: %{failures: 1_000}}
             )

    assert capped == :timer.minutes(5)
  end
end
