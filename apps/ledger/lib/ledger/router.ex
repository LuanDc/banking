defmodule Ledger.Router do
  @moduledoc """
  Routes each command to the aggregate that owns it: ledger accounts by `account_id`,
  transaction batches by `batch_id`.
  """

  use Commanded.Commands.Router

  alias Ledger.Aggregates.LedgerAccount
  alias Ledger.Aggregates.TransactionBatch
  alias Ledger.Commands

  # README, D5: a batch into an account that is not open is rejected.
  middleware(Ledger.Middleware.OpenAccounts)

  identify(LedgerAccount, by: :account_id, prefix: "ledger-account-")
  identify(TransactionBatch, by: :batch_id, prefix: "transaction-batch-")

  dispatch([Commands.OpenLedgerAccount, Commands.CloseLedgerAccount], to: LedgerAccount)
  dispatch(Commands.BookTransactionBatch, to: TransactionBatch)
end
