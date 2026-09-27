defmodule Ledger.Aggregates.TransactionBatchTest do
  use ExUnit.Case, async: true

  alias Ledger.Aggregates.TransactionBatch
  alias Ledger.Commands.BookTransactionBatch
  alias Ledger.Events.LedgerBatchBooked
  alias Ledger.Events.LedgerBatchRejected
  alias Ledger.LedgerEntry

  describe "BookTransactionBatch" do
    test "emits LedgerBatchBooked for a balanced batch" do
      entries = [debit("acc-1", 1_000), credit("acc-2", 1_000)]

      assert %LedgerBatchBooked{batch_id: "batch-1", transfer_id: "corr-1", entries: ^entries} =
               book(entries)
    end

    test "emits LedgerBatchRejected when debits and credits differ" do
      assert %LedgerBatchRejected{
               batch_id: "batch-1",
               transfer_id: "corr-1",
               reason: :unbalanced
             } = book([debit("acc-1", 1_000), credit("acc-2", 999)])
    end

    test "rejects an empty batch, balanced only because there is nothing in it" do
      assert %LedgerBatchRejected{reason: :empty} = book([])
    end

    test "rejects a negative amount, which would flip the entry's side" do
      assert %LedgerBatchRejected{reason: :invalid_amount} =
               book([debit("acc-1", -100), credit("acc-2", -100)])
    end

    test "rejects a zero amount, which moves no money" do
      assert %LedgerBatchRejected{reason: :invalid_amount} =
               book([credit("acc-1", 0), credit("acc-2", 0)])
    end

    test "rejects an amount that is not an integer number of cents" do
      assert %LedgerBatchRejected{reason: :invalid_amount} =
               book([debit("acc-1", 10.5), credit("acc-2", 10.5)])
    end

    test "rejects an entry that is neither a debit nor a credit" do
      stray = %LedgerEntry{account_id: "acc-3", type: :refund, amount: 500}

      assert %LedgerBatchRejected{reason: :invalid_entry_type} =
               book([debit("acc-1", 1_000), credit("acc-2", 1_000), stray])
    end

    test "a rejection carries the batch's entries, so the sender knows whom to compensate" do
      entries = [debit("acc-1", 1_000), credit("acc-2", 999)]

      assert %LedgerBatchRejected{entries: ^entries} = book(entries)
    end

    test "rejects a batch touching an account that is not open (D5)" do
      command = %BookTransactionBatch{
        batch_id: "batch-1",
        transfer_id: "corr-1",
        entries: [debit("acc-1", 1_000), credit("acc-2", 1_000)],
        accounts_not_open: ["acc-2"]
      }

      assert %LedgerBatchRejected{reason: :account_not_open} =
               TransactionBatch.execute(%TransactionBatch{}, command)
    end

    test "ignores a redelivered command for a batch that was already booked" do
      booked = %TransactionBatch{batch_id: "batch-1", status: :booked}

      assert [] = book([debit("acc-1", 1_000), credit("acc-2", 1_000)], booked)
    end

    test "ignores a redelivered command for a batch that was already rejected" do
      rejected = %TransactionBatch{batch_id: "batch-1", status: :rejected}

      assert [] = book([], rejected)
    end
  end

  describe "applying LedgerBatchBooked" do
    test "marks the batch as booked" do
      event = %LedgerBatchBooked{
        batch_id: "batch-1",
        transfer_id: "corr-1",
        entries: [debit("acc-1", 1_000), credit("acc-2", 1_000)]
      }

      assert %TransactionBatch{batch_id: "batch-1", status: :booked} =
               TransactionBatch.apply(%TransactionBatch{}, event)
    end
  end

  describe "applying LedgerBatchRejected" do
    test "marks the batch as rejected" do
      event = %LedgerBatchRejected{batch_id: "batch-1", transfer_id: "corr-1", reason: :empty}

      assert %TransactionBatch{batch_id: "batch-1", status: :rejected} =
               TransactionBatch.apply(%TransactionBatch{}, event)
    end
  end

  describe "lifespan" do
    test "stops the batch once it is booked" do
      assert TransactionBatch.after_event(%LedgerBatchBooked{}) == :stop
    end

    test "stops the batch once it is rejected" do
      assert TransactionBatch.after_event(%LedgerBatchRejected{}) == :stop
    end

    test "stops a decided batch after a redelivered command, which books nothing" do
      assert TransactionBatch.after_command(%BookTransactionBatch{}) == :stop
    end

    test "stops the batch after an error, since a retry rebuilds it from its one event at most" do
      assert TransactionBatch.after_error(:any_reason) == :stop
    end
  end

  defp book(entries, batch \\ %TransactionBatch{}) do
    command = %BookTransactionBatch{
      batch_id: "batch-1",
      transfer_id: "corr-1",
      entries: entries
    }

    TransactionBatch.execute(batch, command)
  end

  defp debit(account_id, amount),
    do: %LedgerEntry{account_id: account_id, type: :debit, amount: amount}

  defp credit(account_id, amount),
    do: %LedgerEntry{account_id: account_id, type: :credit, amount: amount}
end
