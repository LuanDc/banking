defmodule Ledger.Handlers.Projectors.BalancesProjector do
  @moduledoc """
  Projects booked batches into `account_balances`, the BalanceView (README, section 7).
  """

  use Commanded.Projections.Ecto,
    application: Ledger.App,
    repo: Ledger.Repo,
    name: "balances_projector"

  alias Ledger.Events.LedgerBatchBooked
  alias Ledger.Projections.AccountBalance

  project %LedgerBatchBooked{} = event, metadata, fn multi ->
    Ecto.Multi.insert_all(
      multi,
      :account_balances,
      AccountBalance,
      totals_by_account(event.entries, metadata.created_at),
      conflict_target: [:account_id],
      on_conflict:
        from(b in AccountBalance,
          update: [
            set: [
              debit_total: fragment("? + EXCLUDED.debit_total", b.debit_total),
              credit_total: fragment("? + EXCLUDED.credit_total", b.credit_total),
              updated_at: fragment("EXCLUDED.updated_at")
            ]
          ]
        )
    )
  end

  # One row per account: an upsert cannot touch the same row twice in one statement.
  defp totals_by_account(entries, booked_at) do
    entries
    |> Enum.group_by(& &1.account_id)
    |> Enum.map(fn {account_id, account_entries} ->
      %{
        account_id: account_id,
        debit_total: total(account_entries, :debit),
        credit_total: total(account_entries, :credit),
        updated_at: booked_at
      }
    end)
  end

  defp total(entries, type) do
    entries
    |> Enum.filter(&(&1.type == type))
    |> Enum.map(& &1.amount)
    |> Enum.sum()
  end

  # `mix commanded.reset` calls this before replaying the event store from the origin (README,
  # D11): the read model and its version start empty.
  @impl Commanded.Event.Handler
  def before_reset do
    {:ok, _changes} =
      Ecto.Multi.new()
      |> Ecto.Multi.delete_all(:read_model, AccountBalance)
      |> Ecto.Multi.delete_all(
        :projection_version,
        from(v in ProjectionVersion, where: v.projection_name == "balances_projector")
      )
      |> Ledger.Repo.transaction()

    :ok
  end
end
