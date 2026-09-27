defmodule Accounts.Messaging.LedgerCommandsTest do
  use ExUnit.Case, async: true

  alias Accounts.Events.CreditAuthorized
  alias Accounts.Events.CustomerAccountClosed
  alias Accounts.Events.CustomerAccountOpened
  alias Accounts.Messaging.BatchId
  alias Accounts.Messaging.LedgerCommands

  @metadata %{event_id: "evt-1", correlation_id: "corr-1"}

  test "opens the ledger account of a newly opened customer account" do
    event = %CustomerAccountOpened{account_id: "acc-1", customer_id: "cus-1"}

    assert LedgerCommands.for_event(event, @metadata) == %{
             message_id: "evt-1",
             correlation_id: "corr-1",
             type: "OpenLedgerAccount",
             payload: %{account_id: "acc-1"}
           }
  end

  test "closes the ledger account of a closed customer account" do
    event = %CustomerAccountClosed{account_id: "acc-1"}

    assert LedgerCommands.for_event(event, @metadata) == %{
             message_id: "evt-1",
             correlation_id: "corr-1",
             type: "CloseLedgerAccount",
             payload: %{account_id: "acc-1"}
           }
  end

  test "books an authorized credit: a debit to the source, a credit to the destination" do
    event = %CreditAuthorized{
      account_id: "acc-2",
      amount: 400,
      transfer_id: "corr-1",
      from_account_id: "acc-1"
    }

    # README, D17: the batch has an id of its own, derived from the transfer's, so a redelivered
    # command hits a batch already decided (D4).
    assert LedgerCommands.for_event(event, @metadata) == %{
             message_id: "evt-1",
             correlation_id: "corr-1",
             type: "BookTransactionBatch",
             payload: %{
               batch_id: BatchId.settlement("corr-1"),
               transfer_id: "corr-1",
               entries: [
                 %{account_id: "acc-1", type: "debit", amount: 400},
                 %{account_id: "acc-2", type: "credit", amount: 400}
               ]
             }
           }
  end
end
