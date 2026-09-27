defmodule Ledger.TransactionBatchesTest do
  use Ledger.DataCase, async: true

  alias Ledger.TransactionBatches

  describe "get_batch/1" do
    test "returns the batch with its entries in order" do
      # A fresh id: async tests inserting the same (batch_id, position) deadlock on its index.
      batch_id = Ecto.UUID.generate()

      insert(:statement_entry,
        batch_id: batch_id,
        transfer_id: "corr-1",
        position: 1,
        type: :credit
      )

      insert(:statement_entry,
        batch_id: batch_id,
        transfer_id: "corr-1",
        position: 0,
        type: :debit
      )

      assert {:ok, %{batch_id: ^batch_id, transfer_id: "corr-1", entries: entries}} =
               TransactionBatches.get_batch(batch_id)

      assert Enum.map(entries, & &1.type) == [:debit, :credit]
    end

    test "is not found for a batch that booked nothing" do
      assert {:error, :not_found} = TransactionBatches.get_batch("rejected")
    end
  end

  describe "list_batches/1" do
    test "returns the batches that settle a transfer, each with its entries in order" do
      transfer_id = Ecto.UUID.generate()
      batch_id = Ecto.UUID.generate()

      insert(:statement_entry,
        batch_id: batch_id,
        transfer_id: transfer_id,
        position: 1,
        type: :credit
      )

      insert(:statement_entry,
        batch_id: batch_id,
        transfer_id: transfer_id,
        position: 0,
        type: :debit
      )

      insert(:statement_entry, batch_id: Ecto.UUID.generate(), position: 0)

      assert {:ok, [%{batch_id: ^batch_id, transfer_id: ^transfer_id, entries: entries}]} =
               TransactionBatches.list_batches(transfer_id)

      assert Enum.map(entries, & &1.type) == [:debit, :credit]
    end

    test "is empty for a transfer with no booked batch" do
      assert {:ok, []} = TransactionBatches.list_batches(Ecto.UUID.generate())
    end
  end
end
