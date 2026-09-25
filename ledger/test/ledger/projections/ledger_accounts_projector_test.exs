defmodule Ledger.Projections.LedgerAccountsProjectorTest do
  # Not async: every test writes the same row of projection_versions.
  use Ledger.DataCase, async: false

  alias Ledger.Events.LedgerAccountClosed
  alias Ledger.Events.LedgerAccountOpened
  alias Ledger.Projections.LedgerAccount
  alias Ledger.Projections.LedgerAccountsProjector

  @opened_at ~U[2026-09-25 12:00:00.000000Z]
  @closed_at ~U[2026-09-26 12:00:00.000000Z]

  test "projects an opened account as open" do
    :ok = project(%LedgerAccountOpened{account_id: "acc-1"}, 1, @opened_at)

    assert %LedgerAccount{status: :open, opened_at: @opened_at, closed_at: nil} =
             Repo.get(LedgerAccount, "acc-1")
  end

  test "projects a closed account as closed" do
    :ok = project(%LedgerAccountOpened{account_id: "acc-1"}, 1, @opened_at)
    :ok = project(%LedgerAccountClosed{account_id: "acc-1"}, 2, @closed_at)

    assert %LedgerAccount{status: :closed, closed_at: @closed_at} =
             Repo.get(LedgerAccount, "acc-1")
  end

  test "projects a redelivered event only once" do
    :ok = project(%LedgerAccountOpened{account_id: "acc-1"}, 1, @opened_at)
    :ok = project(%LedgerAccountOpened{account_id: "acc-1"}, 1, @opened_at)

    assert [%LedgerAccount{account_id: "acc-1"}] = Repo.all(LedgerAccount)
  end

  defp project(event, event_number, created_at) do
    LedgerAccountsProjector.handle(event, %{
      handler_name: "ledger_accounts_projector",
      event_number: event_number,
      created_at: created_at
    })
  end
end
