defmodule Ledger.Middleware.OpenAccounts do
  @moduledoc """
  The Ledger's one integrity rule about accounts (README, D5): no entry into an account that is
  not open.

  Before a `BookTransactionBatch` reaches its aggregate, this notes which of its accounts are not
  open, read from the `ledger_accounts` projection. `TransactionBatch` then rejects the batch, so
  the sender hears `LedgerBatchRejected` and compensates, and the aggregate stays a pure function
  of its command. The projection is strongly consistent: an `OpenLedgerAccount` is visible here
  as soon as its dispatch returns.
  """

  @behaviour Commanded.Middleware

  import Ecto.Query

  alias Commanded.Middleware.Pipeline
  alias Ledger.Commands.BookTransactionBatch
  alias Ledger.Projections.LedgerAccount
  alias Ledger.Repo

  @impl Commanded.Middleware
  def before_dispatch(%Pipeline{command: %BookTransactionBatch{} = command} = pipeline) do
    account_ids =
      command.entries
      |> Enum.map(& &1.account_id)
      |> Enum.uniq()

    open =
      LedgerAccount
      |> where([account], account.account_id in ^account_ids and account.status == :open)
      |> select([account], account.account_id)
      |> Repo.all()

    %Pipeline{pipeline | command: %{command | accounts_not_open: account_ids -- open}}
  end

  def before_dispatch(%Pipeline{} = pipeline), do: pipeline

  @impl Commanded.Middleware
  def after_dispatch(%Pipeline{} = pipeline), do: pipeline

  @impl Commanded.Middleware
  def after_failure(%Pipeline{} = pipeline), do: pipeline
end
