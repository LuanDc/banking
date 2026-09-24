defmodule Ledger.TransactionBatchTest do
  use ExUnit.Case, async: true

  alias Ledger.Commands.BookTransactionBatch
  alias Ledger.Events.LedgerBatchBooked
  alias Ledger.Events.LedgerBatchRejected
  alias Ledger.LedgerEntry
  alias Ledger.TransactionBatch

  describe "BookTransactionBatch" do
    test "emits LedgerBatchBooked for a balanced batch" do
      entries = [debit("acc-1", 1_000), credit("acc-2", 1_000)]

      assert %LedgerBatchBooked{batch_id: "batch-1", correlation_id: "corr-1", entries: ^entries} =
               book(entries)
    end

    test "emits LedgerBatchRejected when debits and credits differ" do
      assert %LedgerBatchRejected{
               batch_id: "batch-1",
               correlation_id: "corr-1",
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
  end

  defp book(entries, batch \\ %TransactionBatch{}) do
    command = %BookTransactionBatch{
      batch_id: "batch-1",
      correlation_id: "corr-1",
      entries: entries
    }

    TransactionBatch.execute(batch, command)
  end

  defp debit(account_id, amount),
    do: %LedgerEntry{account_id: account_id, type: :debit, amount: amount}

  defp credit(account_id, amount),
    do: %LedgerEntry{account_id: account_id, type: :credit, amount: amount}
end
