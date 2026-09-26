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
      [] ->
        {:error, :not_found}

      [first | _rest] ->
        {:ok,
         %{
           batch_id: batch_id,
           correlation_id: first.correlation_id,
           booked_at: first.booked_at,
           entries: entries
         }}
    end
  end
end
