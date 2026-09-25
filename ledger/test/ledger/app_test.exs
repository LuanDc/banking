defmodule Ledger.AppTest do
  # Smoke tests of the Commanded wiring: router, event store and serializer. The rules
  # themselves are covered by the pure aggregate tests.
  use ExUnit.Case, async: false

  @moduletag :integration

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
end
