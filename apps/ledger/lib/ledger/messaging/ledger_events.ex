defmodule Ledger.Messaging.LedgerEvents do
  @moduledoc """
  The Ledger's event contract for other contexts (README, D3): the messages it publishes on the
  `ledger.events` topic exchange, whoever listens.

  A message carries the event `type`, a `routing_key` for subscribers to bind on, its `payload`
  and a `message_id` taken from the stored event. A batch carries its entries, booked or not, so
  a subscriber knows which accounts it touched without asking.
  """

  alias Ledger.Events.LedgerBatchBooked
  alias Ledger.Events.LedgerBatchRejected

  @doc "Whether another context needs the event. The rest stays internal (README, D3)."
  def published?(%LedgerBatchBooked{}), do: true
  def published?(%LedgerBatchRejected{}), do: true
  def published?(_event), do: false

  def for_event(%LedgerBatchBooked{} = event, metadata) do
    message("LedgerBatchBooked", "ledger.batch.booked", metadata, %{
      batch_id: event.batch_id,
      correlation_id: event.correlation_id,
      entries: Enum.map(event.entries, &entry/1)
    })
  end

  def for_event(%LedgerBatchRejected{} = event, metadata) do
    message("LedgerBatchRejected", "ledger.batch.rejected", metadata, %{
      batch_id: event.batch_id,
      correlation_id: event.correlation_id,
      reason: Atom.to_string(event.reason),
      entries: Enum.map(event.entries, &entry/1)
    })
  end

  defp entry(entry) do
    %{account_id: entry.account_id, type: Atom.to_string(entry.type), amount: entry.amount}
  end

  defp message(type, routing_key, metadata, payload) do
    %{message_id: metadata.event_id, type: type, routing_key: routing_key, payload: payload}
  end
end
