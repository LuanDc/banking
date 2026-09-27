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

  # An account's process leaves memory after 5 minutes without a command (LedgerAccount's lifespan).
  dispatch([Commands.OpenLedgerAccount, Commands.CloseLedgerAccount],
    to: LedgerAccount,
    lifespan: LedgerAccount
  )

  # A batch's process stops once it is decided (TransactionBatch's lifespan).
  dispatch(Commands.BookTransactionBatch, to: TransactionBatch, lifespan: TransactionBatch)
end
