defmodule Ledger.Handlers.Projectors.StatementProjectorTest do
  # Not async: every test writes the same row of projection_versions.
  use Ledger.DataCase, async: false

  alias Ledger.Events.LedgerBatchBooked
  alias Ledger.Handlers.Projectors.StatementProjector
  alias Ledger.LedgerEntry
  alias Ledger.Projections.StatementEntry

  @booked_at ~U[2026-09-25 12:00:00.000000Z]

  test "records every entry of a booked batch, in the batch's order" do
    :ok = project(booked_batch(), 1)

    assert [
             %StatementEntry{
               batch_id: "batch-1",
               transfer_id: "corr-1",
               position: 0,
               account_id: "pix",
               type: :debit,
               amount: 1_000,
               booked_at: @booked_at
             },
             %StatementEntry{position: 1, account_id: "acc-1", type: :credit, amount: 1_000}
           ] = Repo.all(from e in StatementEntry, order_by: e.position)
  end

  test "projects a redelivered batch only once" do
    :ok = project(booked_batch(), 1)
    :ok = project(booked_batch(), 1)

    assert Repo.aggregate(StatementEntry, :count) == 2
  end

  test "a reset clears the read model, so the replay starts from scratch" do
    :ok = project(booked_batch(), 1)
    :ok = StatementProjector.before_reset()

    assert Repo.all(StatementEntry) == []

    :ok = project(booked_batch(), 1)

    assert Repo.aggregate(StatementEntry, :count) == 2
  end

  defp booked_batch do
    %LedgerBatchBooked{
      batch_id: "batch-1",
      transfer_id: "corr-1",
      entries: [
        %LedgerEntry{account_id: "pix", type: :debit, amount: 1_000},
        %LedgerEntry{account_id: "acc-1", type: :credit, amount: 1_000}
      ]
    }
  end

  defp project(event, event_number) do
    StatementProjector.handle(event, %{
      handler_name: "statement_projector",
      event_number: event_number,
      created_at: @booked_at
    })
  end
end
