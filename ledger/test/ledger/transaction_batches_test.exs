defmodule Ledger.TransactionBatchesTest do
  use Ledger.DataCase, async: true

  alias Ledger.TransactionBatches

  describe "get_batch/1" do
    test "returns the batch with its entries in order" do
      insert(:statement_entry,
        batch_id: "batch-1",
        correlation_id: "corr-1",
        position: 1,
        type: :credit
      )

      insert(:statement_entry,
        batch_id: "batch-1",
        correlation_id: "corr-1",
        position: 0,
        type: :debit
      )

      assert {:ok, %{batch_id: "batch-1", correlation_id: "corr-1", entries: entries}} =
               TransactionBatches.get_batch("batch-1")

      assert Enum.map(entries, & &1.type) == [:debit, :credit]
    end

    test "is not found for a batch that booked nothing" do
      assert {:error, :not_found} = TransactionBatches.get_batch("rejected")
    end
  end
end
