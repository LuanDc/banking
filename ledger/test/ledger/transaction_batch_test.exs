defmodule Ledger.TransactionBatchTest do
  use ExUnit.Case, async: true

  alias Ledger.Commands.BookTransactionBatch
  alias Ledger.Events.LedgerBatchBooked
  alias Ledger.Events.LedgerBatchRejected
  alias Ledger.LedgerEntry
  alias Ledger.TransactionBatch

  describe "BookTransactionBatch" do
    test "emits LedgerBatchBooked for a balanced batch" do
      entries = [
        %LedgerEntry{account_id: "acc-1", type: :debit, amount: 1_000},
        %LedgerEntry{account_id: "acc-2", type: :credit, amount: 1_000}
      ]

      command = %BookTransactionBatch{
        batch_id: "batch-1",
        correlation_id: "corr-1",
        entries: entries
      }

      assert %LedgerBatchBooked{batch_id: "batch-1", correlation_id: "corr-1", entries: ^entries} =
               TransactionBatch.execute(%TransactionBatch{}, command)
    end

    test "emits LedgerBatchRejected when debits and credits differ" do
      entries = [
        %LedgerEntry{account_id: "acc-1", type: :debit, amount: 1_000},
        %LedgerEntry{account_id: "acc-2", type: :credit, amount: 999}
      ]

      command = %BookTransactionBatch{
        batch_id: "batch-1",
        correlation_id: "corr-1",
        entries: entries
      }

      assert %LedgerBatchRejected{
               batch_id: "batch-1",
               correlation_id: "corr-1",
               reason: :unbalanced
             } = TransactionBatch.execute(%TransactionBatch{}, command)
    end
  end
end
