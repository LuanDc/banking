defmodule Ledger.Handlers.Projectors.StatementProjector do
  @moduledoc """
  Projects booked batches into `ledger_entries`, the StatementView (README, section 7).
  """

  use Commanded.Projections.Ecto,
    application: Ledger.App,
    repo: Ledger.Repo,
    name: "statement_projector"

  alias Ledger.Events.LedgerBatchBooked
  alias Ledger.Projections.StatementEntry

  project %LedgerBatchBooked{} = event, metadata, fn multi ->
    entries =
      event.entries
      |> Enum.with_index()
      |> Enum.map(fn {entry, position} ->
        %{
          batch_id: event.batch_id,
          correlation_id: event.correlation_id,
          position: position,
          account_id: entry.account_id,
          type: entry.type,
          amount: entry.amount,
          booked_at: metadata.created_at
        }
      end)

    Ecto.Multi.insert_all(multi, :ledger_entries, StatementEntry, entries)
  end

  # `mix commanded.reset` calls this before replaying the event store from the origin (README,
  # D11): the read model and its version start empty.
  @impl Commanded.Event.Handler
  def before_reset do
    {:ok, _changes} =
      Ecto.Multi.new()
      |> Ecto.Multi.delete_all(:read_model, StatementEntry)
      |> Ecto.Multi.delete_all(
        :projection_version,
        from(v in ProjectionVersion, where: v.projection_name == "statement_projector")
      )
      |> Ledger.Repo.transaction()

    :ok
  end
end
