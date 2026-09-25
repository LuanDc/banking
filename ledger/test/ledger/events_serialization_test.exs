defmodule Ledger.EventsSerializationTest do
  use ExUnit.Case, async: true

  alias Commanded.Serialization.JsonSerializer
  alias Ledger.Events
  alias Ledger.LedgerEntry

  # One sample of every event the Ledger aggregates emit. The event store keeps them as JSON,
  # and aggregates and handlers read them back, so each one must round-trip unchanged.
  @events [
    %Events.LedgerAccountOpened{account_id: "acc-1"},
    %Events.LedgerAccountClosed{account_id: "acc-1"},
    %Events.LedgerBatchBooked{
      batch_id: "batch-1",
      correlation_id: "corr-1",
      entries: [
        %LedgerEntry{account_id: "acc-1", type: :debit, amount: 1_000},
        %LedgerEntry{account_id: "acc-2", type: :credit, amount: 1_000}
      ]
    },
    %Events.LedgerBatchRejected{
      batch_id: "batch-1",
      correlation_id: "corr-1",
      reason: :unbalanced,
      entries: [
        %LedgerEntry{account_id: "acc-1", type: :debit, amount: 1_000},
        %LedgerEntry{account_id: "acc-2", type: :credit, amount: 999}
      ]
    }
  ]

  for event <- @events do
    @event event
    test "#{inspect(event.__struct__)} round-trips through the JSON serializer" do
      type = Atom.to_string(@event.__struct__)

      assert @event ==
               @event |> JsonSerializer.serialize() |> JsonSerializer.deserialize(type: type)
    end
  end
end
