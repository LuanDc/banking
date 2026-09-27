defmodule Ledger.Projections.TrialBalanceTest do
  # Not async: the balances projector writes a shared row of projection_versions.
  use Ledger.DataCase, async: false

  alias Ledger.Events.LedgerBatchBooked
  alias Ledger.Handlers.Projectors.BalancesProjector
  alias Ledger.LedgerEntry
  alias Ledger.Projections.TrialBalance

  test "is zero before anything is booked" do
    assert %TrialBalance{debit_total: 0, credit_total: 0} = Repo.one(TrialBalance)
  end

  test "totals every account's debits and credits (README, section 4.1)" do
    :ok = book(1, [entry("pix", :debit, 1_000), entry("acc-1", :credit, 1_000)])
    :ok = book(2, [entry("acc-1", :debit, 400), entry("acc-2", :credit, 400)])

    assert %TrialBalance{debit_total: 1_400, credit_total: 1_400} = Repo.one(TrialBalance)
  end

  defp book(event_number, entries) do
    batch_id = "batch-#{event_number}"
    event = %LedgerBatchBooked{batch_id: batch_id, transfer_id: batch_id, entries: entries}

    BalancesProjector.handle(event, %{
      handler_name: "balances_projector",
      event_number: event_number,
      created_at: DateTime.utc_now()
    })
  end

  defp entry(account_id, type, amount),
    do: %LedgerEntry{account_id: account_id, type: type, amount: amount}
end
