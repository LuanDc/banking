defmodule Ledger.Projections.LedgerAccountsProjector do
  @moduledoc """
  Projects the lifecycle of ledger accounts into `ledger_accounts` (README, D5).

  Strongly consistent, so a command dispatched with `consistency: :strong` returns only once
  the account shows up here.
  """

  use Commanded.Projections.Ecto,
    application: Ledger.App,
    repo: Ledger.Repo,
    name: "ledger_accounts_projector",
    consistency: :strong

  alias Ledger.Events.LedgerAccountClosed
  alias Ledger.Events.LedgerAccountOpened
  alias Ledger.Projections.LedgerAccount

  project(%LedgerAccountOpened{} = event, metadata, fn multi ->
    Ecto.Multi.insert(multi, :ledger_account, %LedgerAccount{
      account_id: event.account_id,
      status: :open,
      opened_at: metadata.created_at
    })
  end)

  project(%LedgerAccountClosed{} = event, metadata, fn multi ->
    Ecto.Multi.update_all(
      multi,
      :ledger_account,
      from(a in LedgerAccount, where: a.account_id == ^event.account_id),
      set: [status: :closed, closed_at: metadata.created_at]
    )
  end)
end
