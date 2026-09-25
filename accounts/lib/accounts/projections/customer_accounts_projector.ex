defmodule Accounts.Projections.CustomerAccountsProjector do
  @moduledoc """
  Projects the lifecycle of customer accounts into `customer_accounts` and their FSM history
  into `customer_account_status_changes` (README, section 7).
  """

  use Commanded.Projections.Ecto,
    application: Accounts.App,
    repo: Accounts.Repo,
    name: "customer_accounts_projector"

  alias Accounts.Events.CustomerAccountActivated
  alias Accounts.Events.CustomerAccountBlocked
  alias Accounts.Events.CustomerAccountClosed
  alias Accounts.Events.CustomerAccountFrozen
  alias Accounts.Events.CustomerAccountOpened
  alias Accounts.Events.CustomerAccountUnblocked
  alias Accounts.Events.CustomerAccountUnfrozen
  alias Accounts.Projections.CustomerAccount
  alias Accounts.Projections.StatusChange

  project(%CustomerAccountOpened{} = event, metadata, fn multi ->
    multi
    |> Ecto.Multi.insert(:customer_account, %CustomerAccount{
      account_id: event.account_id,
      customer_id: event.customer_id,
      status: :pending_kyc,
      opened_at: metadata.created_at,
      updated_at: metadata.created_at
    })
    |> record_change(event, metadata, :pending_kyc, nil)
  end)

  project(%CustomerAccountActivated{} = event, metadata, fn multi ->
    change_status(multi, event, metadata, :active, nil)
  end)

  project(%CustomerAccountBlocked{} = event, metadata, fn multi ->
    change_status(multi, event, metadata, :blocked, event.reason)
  end)

  project(%CustomerAccountUnblocked{} = event, metadata, fn multi ->
    change_status(multi, event, metadata, :active, nil)
  end)

  project(%CustomerAccountFrozen{} = event, metadata, fn multi ->
    change_status(multi, event, metadata, :frozen, event.reason)
  end)

  project(%CustomerAccountUnfrozen{} = event, metadata, fn multi ->
    change_status(multi, event, metadata, :active, nil)
  end)

  project(%CustomerAccountClosed{} = event, metadata, fn multi ->
    multi
    |> change_status(event, metadata, :closed, nil)
    |> Ecto.Multi.update_all(:closed_at, account(event), set: [closed_at: metadata.created_at])
  end)

  defp change_status(multi, event, metadata, status, reason) do
    multi
    |> Ecto.Multi.update_all(:customer_account, account(event),
      set: [status: status, status_reason: reason, updated_at: metadata.created_at]
    )
    |> record_change(event, metadata, status, reason)
  end

  defp record_change(multi, %event_type{} = event, metadata, status, reason) do
    Ecto.Multi.insert(multi, :status_change, %StatusChange{
      account_id: event.account_id,
      event: event_type |> Module.split() |> List.last(),
      status: status,
      reason: reason,
      occurred_at: metadata.created_at
    })
  end

  defp account(event), do: from(a in CustomerAccount, where: a.account_id == ^event.account_id)
end
