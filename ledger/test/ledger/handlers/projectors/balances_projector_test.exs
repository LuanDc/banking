defmodule Ledger.Handlers.Projectors.BalancesProjectorTest do
  # Not async: every test writes the same row of projection_versions.
  use Ledger.DataCase, async: false

  alias Ledger.Events.LedgerBatchBooked
  alias Ledger.Handlers.Projectors.BalancesProjector
  alias Ledger.LedgerEntry
  alias Ledger.Projections.AccountBalance

  @booked_at ~U[2026-09-25 12:00:00.000000Z]

  test "adds each entry to its account's debit or credit total" do
    :ok = project(batch("batch-1", [debit("pix", 1_000), credit("acc-1", 1_000)]), 1)

    assert %AccountBalance{debit_total: 1_000, credit_total: 0, balance: -1_000} =
             Repo.get(AccountBalance, "pix")

    assert %AccountBalance{debit_total: 0, credit_total: 1_000, balance: 1_000} =
             Repo.get(AccountBalance, "acc-1")
  end

  test "sums the entries a batch makes to the same account" do
    entries = [debit("pix", 300), debit("pix", 200), credit("acc-1", 500)]
    :ok = project(batch("batch-1", entries), 1)

    assert %AccountBalance{debit_total: 500} = Repo.get(AccountBalance, "pix")
  end

  test "accumulates across batches" do
    :ok = project(batch("batch-1", [debit("pix", 1_000), credit("acc-1", 1_000)]), 1)
    :ok = project(batch("batch-2", [debit("acc-1", 400), credit("acc-2", 400)]), 2)

    assert %AccountBalance{debit_total: 400, credit_total: 1_000, balance: 600} =
             Repo.get(AccountBalance, "acc-1")
  end

  test "projects a redelivered batch only once" do
    event = batch("batch-1", [debit("pix", 1_000), credit("acc-1", 1_000)])
    :ok = project(event, 1)
    :ok = project(event, 1)

    assert %AccountBalance{credit_total: 1_000} = Repo.get(AccountBalance, "acc-1")
  end

  test "a reset clears the read model, so the replay starts from scratch" do
    event = batch("batch-1", [debit("pix", 1_000), credit("acc-1", 1_000)])
    :ok = project(event, 1)
    :ok = BalancesProjector.before_reset()

    assert Repo.all(AccountBalance) == []

    :ok = project(event, 1)

    assert %AccountBalance{credit_total: 1_000} = Repo.get(AccountBalance, "acc-1")
  end

  defp batch(batch_id, entries) do
    %LedgerBatchBooked{batch_id: batch_id, correlation_id: "corr-" <> batch_id, entries: entries}
  end

  defp debit(account_id, amount),
    do: %LedgerEntry{account_id: account_id, type: :debit, amount: amount}

  defp credit(account_id, amount),
    do: %LedgerEntry{account_id: account_id, type: :credit, amount: amount}

  defp project(event, event_number) do
    BalancesProjector.handle(event, %{
      handler_name: "balances_projector",
      event_number: event_number,
      created_at: @booked_at
    })
  end
end
