defmodule LedgerWeb.BatchJSON do
  def show(%{batch: batch}) do
    %{
      batch_id: batch.batch_id,
      correlation_id: batch.correlation_id,
      booked_at: batch.booked_at,
      entries: Enum.map(batch.entries, &Map.take(&1, [:position, :account_id, :type, :amount]))
    }
  end
end
