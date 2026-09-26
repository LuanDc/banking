defmodule LedgerWeb.BatchController do
  use LedgerWeb, :controller

  alias Ledger.TransactionBatches

  action_fallback LedgerWeb.FallbackController

  def show(conn, %{"batch_id" => batch_id}) do
    with {:ok, batch} <- TransactionBatches.get_batch(batch_id) do
      render(conn, :show, batch: batch)
    end
  end
end
