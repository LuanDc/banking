defmodule Ledger.Messaging.LedgerEventsTest do
  use ExUnit.Case, async: true

  alias Ledger.Events.LedgerAccountOpened
  alias Ledger.Events.LedgerBatchBooked
  alias Ledger.Events.LedgerBatchRejected
  alias Ledger.LedgerEntry
  alias Ledger.Messaging.LedgerEvents

  @metadata %{event_id: "evt-1"}
  @entries [
    %LedgerEntry{account_id: "acc-1", type: :debit, amount: 1_000},
    %LedgerEntry{account_id: "acc-2", type: :credit, amount: 1_000}
  ]
  @payload_entries [
    %{account_id: "acc-1", type: "debit", amount: 1_000},
    %{account_id: "acc-2", type: "credit", amount: 1_000}
  ]

  test "publishes a booked batch with its entries" do
    event = %LedgerBatchBooked{batch_id: "batch-1", transfer_id: "corr-1", entries: @entries}

    assert LedgerEvents.for_event(event, @metadata) == %{
             message_id: "evt-1",
             type: "LedgerBatchBooked",
             routing_key: "ledger.batch.booked",
             payload: %{batch_id: "batch-1", correlation_id: "corr-1", entries: @payload_entries}
           }
  end

  test "publishes a rejected batch with its reason and the entries it would have booked" do
    event = %LedgerBatchRejected{
      batch_id: "batch-1",
      transfer_id: "corr-1",
      reason: :account_not_open,
      entries: @entries
    }

    assert LedgerEvents.for_event(event, @metadata) == %{
             message_id: "evt-1",
             type: "LedgerBatchRejected",
             routing_key: "ledger.batch.rejected",
             payload: %{
               batch_id: "batch-1",
               correlation_id: "corr-1",
               reason: "account_not_open",
               entries: @payload_entries
             }
           }
  end

  test "publishes only the events another context needs (README, D3)" do
    assert LedgerEvents.published?(%LedgerBatchBooked{})
    assert LedgerEvents.published?(%LedgerBatchRejected{})
    refute LedgerEvents.published?(%LedgerAccountOpened{account_id: "acc-1"})
  end
end
