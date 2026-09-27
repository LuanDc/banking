defmodule Accounts.Handlers.Projectors.CustomerAccountsProjector do
  @moduledoc """
  Projects the lifecycle of customer accounts into `customer_accounts` and their FSM history
  into `customer_account_status_changes` (README, section 7).

  It also mirrors the aggregate's available balance (README, D2): posted credits raise it,
  reservations hold it and released reservations give it back.
  """

  use Commanded.Projections.Ecto,
    application: Accounts.App,
    repo: Accounts.Repo,
    name: "customer_accounts_projector"

  alias Accounts.Events.BalanceReleased
  alias Accounts.Events.BalanceReserved
  alias Accounts.Events.CreditPosted
  alias Accounts.Events.CustomerAccountActivated
  alias Accounts.Events.CustomerAccountBlocked
  alias Accounts.Events.CustomerAccountClosed
  alias Accounts.Events.CustomerAccountFrozen
  alias Accounts.Events.CustomerAccountOpened
  alias Accounts.Events.CustomerAccountUnblocked
  alias Accounts.Events.CustomerAccountUnfrozen
  alias Accounts.Handlers.ProjectorFailures
  alias Accounts.Projections.CustomerAccount
  alias Accounts.Projections.StatusChange

  project %CustomerAccountOpened{} = event, metadata, fn multi ->
    multi
    |> Ecto.Multi.insert(:customer_account, %CustomerAccount{
      account_id: event.account_id,
      customer_id: event.customer_id,
      status: :pending_kyc,
      opened_at: metadata.created_at,
      updated_at: metadata.created_at
    })
    |> record_change(event, metadata, :pending_kyc, nil)
  end

  project %CustomerAccountActivated{} = event, metadata, fn multi ->
    change_status(multi, event, metadata, :active, nil)
  end

  project %CustomerAccountBlocked{} = event, metadata, fn multi ->
    change_status(multi, event, metadata, :blocked, event.reason)
  end

  project %CustomerAccountUnblocked{} = event, metadata, fn multi ->
    change_status(multi, event, metadata, :active, nil)
  end

  project %CustomerAccountFrozen{} = event, metadata, fn multi ->
    change_status(multi, event, metadata, :frozen, event.reason)
  end

  project %CustomerAccountUnfrozen{} = event, metadata, fn multi ->
    change_status(multi, event, metadata, :active, nil)
  end

  project %CustomerAccountClosed{} = event, metadata, fn multi ->
    multi
    |> change_status(event, metadata, :closed, nil)
    |> Ecto.Multi.update_all(:closed_at, account(event), set: [closed_at: metadata.created_at])
  end

  project %CreditPosted{} = event, metadata, fn multi ->
    change_balance(multi, event, metadata, event.amount)
  end

  project %BalanceReserved{} = event, metadata, fn multi ->
    change_balance(multi, event, metadata, -event.amount)
  end

  project %BalanceReleased{} = event, metadata, fn multi ->
    change_balance(multi, event, metadata, event.amount)
  end

  defp change_balance(multi, event, metadata, delta) do
    Ecto.Multi.update_all(multi, :customer_account, account(event),
      inc: [available_balance: delta],
      set: [updated_at: metadata.created_at]
    )
  end

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

  # README, D18: waits out the infrastructure, and stops on a bug.
  @impl Commanded.Event.Handler
  def error(error, event, failure_context),
    do: ProjectorFailures.error(error, event, failure_context)

  # `mix commanded.reset` calls this before replaying the event store from the origin (README,
  # D11): the read model and its version start empty.
  @impl Commanded.Event.Handler
  def before_reset do
    {:ok, _changes} =
      Ecto.Multi.new()
      |> Ecto.Multi.delete_all(:status_changes, StatusChange)
      |> Ecto.Multi.delete_all(:customer_accounts, CustomerAccount)
      |> Ecto.Multi.delete_all(
        :projection_version,
        from(v in ProjectionVersion, where: v.projection_name == "customer_accounts_projector")
      )
      |> Accounts.Repo.transaction()

    :ok
  end
end
