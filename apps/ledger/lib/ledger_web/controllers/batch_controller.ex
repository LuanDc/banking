defmodule LedgerWeb.BatchController do
  use LedgerWeb, :controller

  alias Ledger.TransactionBatches

  action_fallback LedgerWeb.FallbackController

  def index(conn, %{"transfer_id" => transfer_id}) do
    with {:ok, batches} <- TransactionBatches.list_batches(transfer_id) do
      render(conn, :index, batches: batches)
    end
  end

  def index(_conn, _params), do: {:error, :invalid_query}

  def show(conn, %{"batch_id" => batch_id}) do
    with {:ok, batch} <- TransactionBatches.get_batch(batch_id) do
      render(conn, :show, batch: batch)
    end
  end
end
