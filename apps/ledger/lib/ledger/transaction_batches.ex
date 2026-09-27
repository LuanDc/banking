defmodule Ledger.TransactionBatches do
  @moduledoc """
  Entry point of the transaction batches context, for the API: booked batches, read from the
  statement (README, section 7). A rejected batch booked nothing, so it is not found.
  """

  import Ecto.Query

  alias Ledger.Projections.StatementEntry
  alias Ledger.Repo

  def get_batch(batch_id) do
    entries =
      StatementEntry
      |> where(batch_id: ^batch_id)
      |> order_by(:position)
      |> Repo.all()

    case entries do
      [] -> {:error, :not_found}
      entries -> {:ok, batch(entries)}
    end
  end

  @doc """
  The booked batches that settle a transfer, oldest first (README, D17): a batch has an id of its
  own and names the transfer it settles.
  """
  def list_batches(transfer_id) do
    batches =
      StatementEntry
      |> where(transfer_id: ^transfer_id)
      |> order_by([:batch_id, :position])
      |> Repo.all()
      |> Enum.chunk_by(& &1.batch_id)
      |> Enum.map(&batch/1)
      |> Enum.sort_by(& &1.booked_at, DateTime)

    {:ok, batches}
  end

  defp batch([first | _rest] = entries) do
    %{
      batch_id: first.batch_id,
      transfer_id: first.transfer_id,
      booked_at: first.booked_at,
      entries: entries
    }
  end
end
