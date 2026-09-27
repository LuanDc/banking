defmodule LedgerWeb.BatchJSON do
  def index(%{batches: batches}), do: %{data: Enum.map(batches, &show(%{batch: &1}))}

  def show(%{batch: batch}) do
    %{
      batch_id: batch.batch_id,
      transfer_id: batch.transfer_id,
      booked_at: batch.booked_at,
      entries: Enum.map(batch.entries, &Map.take(&1, [:position, :account_id, :type, :amount]))
    }
  end
end
