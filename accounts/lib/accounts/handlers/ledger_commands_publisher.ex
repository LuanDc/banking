defmodule Accounts.Handlers.LedgerCommandsPublisher do
  @moduledoc """
  Publishes the Ledger commands caused by Account Management events (README, D3 and D5).

  It reads the event store through a durable subscription, so the event store is the outbox:
  an event is acknowledged only after its message was published.
  """

  use Commanded.Event.Handler,
    application: Accounts.App,
    name: "ledger_commands_publisher",
    start_from: :origin

  alias Accounts.Events.CustomerAccountClosed
  alias Accounts.Events.CustomerAccountOpened
  alias Accounts.Messaging.LedgerCommands
  alias Accounts.Messaging.Publisher
  alias Commanded.Event.FailureContext

  @max_retry_delay :timer.minutes(5)

  @impl Commanded.Event.Handler
  def handle(%CustomerAccountOpened{} = event, metadata), do: publish(event, metadata)

  def handle(%CustomerAccountClosed{} = event, metadata), do: publish(event, metadata)

  # A failed publish is retried with a growing delay and never skipped: the subscription
  # does not move past an event until its message is out.
  @impl Commanded.Event.Handler
  def error(_error, _event, %FailureContext{context: context} = failure_context) do
    failures = Map.get(context, :failures, 0) + 1
    delay = min(failures * failures * 1_000, @max_retry_delay)

    {:retry, delay, %{failure_context | context: Map.put(context, :failures, failures)}}
  end

  defp publish(event, metadata) do
    event
    |> LedgerCommands.for_event(metadata)
    |> Publisher.publish()
  end
end
