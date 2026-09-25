defmodule Ledger.Handlers.LedgerEventsPublisher do
  @moduledoc """
  Publishes the Ledger's events that other contexts need (README, D3).

  It reads the event store through a durable subscription, so the event store is the outbox:
  an event is acknowledged only after its message was published.
  """

  use Commanded.Event.Handler,
    application: Ledger.App,
    name: "ledger_events_publisher",
    start_from: :origin

  alias Commanded.Event.FailureContext
  alias Ledger.Messaging.LedgerEvents
  alias Ledger.Messaging.Publisher

  @max_retry_delay :timer.minutes(5)

  @impl Commanded.Event.Handler
  def handle(event, metadata) do
    if LedgerEvents.published?(event) do
      event
      |> LedgerEvents.for_event(metadata)
      |> Publisher.publish()
    else
      :ok
    end
  end

  # A failed publish is retried with a growing delay and never skipped: the subscription
  # does not move past an event until its message is out.
  @impl Commanded.Event.Handler
  def error(_error, _event, %FailureContext{context: context} = failure_context) do
    failures = Map.get(context, :failures, 0) + 1
    delay = min(failures * failures * 1_000, @max_retry_delay)

    {:retry, delay, %{failure_context | context: Map.put(context, :failures, failures)}}
  end
end
