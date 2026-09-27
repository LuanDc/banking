defmodule Ledger.Messaging.InboxTest do
  use ExUnit.Case, async: true

  alias Ledger.Aggregates.TransactionBatch
  alias Ledger.Commands.BookTransactionBatch
  alias Ledger.Commands.CloseLedgerAccount
  alias Ledger.Commands.OpenLedgerAccount
  alias Ledger.Events.LedgerBatchRejected
  alias Ledger.LedgerEntry
  alias Ledger.Messaging.Inbox

  # Messages arrive as decoded JSON: string keys, string values.

  describe "dispatch_opts/1" do
    test "opens and closes accounts with strong consistency, for the D5 check of the next batch" do
      for command <- [%OpenLedgerAccount{account_id: "a"}, %CloseLedgerAccount{account_id: "a"}] do
        assert Inbox.dispatch_opts(command) == [consistency: :strong]
      end
    end

    test "books a batch with the default consistency" do
      assert Inbox.dispatch_opts(%BookTransactionBatch{}) == []
    end
  end

  describe "to_command/1" do
    test "composes OpenLedgerAccount" do
      message = %{
        "message_id" => "evt-1",
        "type" => "OpenLedgerAccount",
        "payload" => %{"account_id" => "acc-1"}
      }

      assert {:ok, %OpenLedgerAccount{account_id: "acc-1"}} = Inbox.to_command(message)
    end

    test "composes CloseLedgerAccount" do
      message = %{"type" => "CloseLedgerAccount", "payload" => %{"account_id" => "acc-1"}}

      assert {:ok, %CloseLedgerAccount{account_id: "acc-1"}} = Inbox.to_command(message)
    end

    test "composes BookTransactionBatch, with its entries as LedgerEntry" do
      message = %{
        "type" => "BookTransactionBatch",
        "payload" => %{
          "batch_id" => "batch-1",
          "transfer_id" => "corr-1",
          "entries" => [
            %{"account_id" => "acc-1", "type" => "debit", "amount" => 1_000},
            %{"account_id" => "acc-2", "type" => "credit", "amount" => 1_000}
          ]
        }
      }

      assert {:ok,
              %BookTransactionBatch{
                batch_id: "batch-1",
                transfer_id: "corr-1",
                entries: [
                  %LedgerEntry{account_id: "acc-1", type: :debit, amount: 1_000},
                  %LedgerEntry{account_id: "acc-2", type: :credit, amount: 1_000}
                ]
              }} = Inbox.to_command(message)
    end

    test "passes an unknown entry type through, for TransactionBatch to reject" do
      message = %{
        "type" => "BookTransactionBatch",
        "payload" => %{
          "batch_id" => "batch-1",
          "transfer_id" => "corr-1",
          "entries" => [
            %{"account_id" => "acc-1", "type" => "debit", "amount" => 1_000},
            %{"account_id" => "acc-2", "type" => "refund", "amount" => 1_000}
          ]
        }
      }

      assert {:ok, command} = Inbox.to_command(message)

      assert %LedgerBatchRejected{reason: :invalid_entry_type} =
               TransactionBatch.execute(%TransactionBatch{}, command)
    end

    test "rejects a message whose command the Ledger does not accept" do
      message = %{"type" => "DeleteLedgerAccount", "payload" => %{"account_id" => "acc-1"}}

      assert {:error, :unknown_command} = Inbox.to_command(message)
    end
  end
end
