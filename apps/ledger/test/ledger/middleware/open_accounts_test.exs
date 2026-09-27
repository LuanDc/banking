defmodule Ledger.Middleware.OpenAccountsTest do
  use Ledger.DataCase, async: true

  alias Commanded.Middleware.Pipeline
  alias Ledger.Commands.BookTransactionBatch
  alias Ledger.Commands.OpenLedgerAccount
  alias Ledger.LedgerEntry
  alias Ledger.Middleware.OpenAccounts

  test "notes the batch's accounts that are closed or unknown (README, D5)" do
    open = insert(:ledger_account)
    closed = insert(:ledger_account, status: :closed)

    command = %BookTransactionBatch{
      batch_id: "batch-1",
      transfer_id: "corr-1",
      entries: [
        %LedgerEntry{account_id: open.account_id, type: :debit, amount: 1_000},
        %LedgerEntry{account_id: closed.account_id, type: :credit, amount: 500},
        %LedgerEntry{account_id: "unknown", type: :credit, amount: 500}
      ]
    }

    %Pipeline{command: command} = OpenAccounts.before_dispatch(%Pipeline{command: command})

    assert Enum.sort(command.accounts_not_open) == Enum.sort([closed.account_id, "unknown"])
  end

  test "leaves any other command as it is" do
    pipeline = %Pipeline{command: %OpenLedgerAccount{account_id: "acc-1"}}

    assert OpenAccounts.before_dispatch(pipeline) == pipeline
  end
end
