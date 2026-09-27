defmodule Ledger.AppTest do
  # Smoke tests of the Commanded wiring: router, event store and serializer. The rules
  # themselves are covered by the pure aggregate tests. DataCase, because dispatching a batch
  # reads the open ledger accounts (README, D5).
  use Ledger.DataCase, async: false

  @moduletag :integration

  alias Commanded.Registration
  alias Ledger.Aggregates.LedgerAccount
  alias Ledger.Aggregates.TransactionBatch
  alias Ledger.App
  alias Ledger.Commands.BookTransactionBatch
  alias Ledger.Commands.CloseLedgerAccount
  alias Ledger.Commands.OpenLedgerAccount
  alias Ledger.LedgerEntry

  # The event store has no sandbox: fresh ids keep each stream apart from other runs.

  test "dispatches to LedgerAccount, which is rebuilt from its stored events" do
    account_id = Ecto.UUID.generate()

    assert :ok = App.dispatch(%OpenLedgerAccount{account_id: account_id})
    assert :ok = App.dispatch(%CloseLedgerAccount{account_id: account_id})
  end

  test "dispatches to TransactionBatch" do
    command = %BookTransactionBatch{
      batch_id: Ecto.UUID.generate(),
      correlation_id: "corr-1",
      entries: [
        %LedgerEntry{account_id: "acc-1", type: :debit, amount: 1_000},
        %LedgerEntry{account_id: "acc-2", type: :credit, amount: 1_000}
      ]
    }

    assert :ok = App.dispatch(command)
  end

  test "stops a batch's process once it is decided, and keeps the account's" do
    account_id = Ecto.UUID.generate()
    batch_id = Ecto.UUID.generate()

    assert :ok = App.dispatch(%OpenLedgerAccount{account_id: account_id})

    assert :ok =
             App.dispatch(%BookTransactionBatch{
               batch_id: batch_id,
               correlation_id: "corr-1",
               entries: [
                 %LedgerEntry{account_id: account_id, type: :debit, amount: 1_000},
                 %LedgerEntry{account_id: account_id, type: :credit, amount: 1_000}
               ]
             })

    assert eventually(fn -> not alive?(TransactionBatch, "transaction-batch-" <> batch_id) end)
    assert alive?(LedgerAccount, "ledger-account-" <> account_id)
  end

  defp alive?(aggregate, uuid) do
    is_pid(Registration.whereis_name(App, {App, aggregate, uuid}))
  end

  defp eventually(check, attempts \\ 50) do
    cond do
      check.() -> true
      attempts == 0 -> false
      true -> Process.sleep(10) && eventually(check, attempts - 1)
    end
  end
end
