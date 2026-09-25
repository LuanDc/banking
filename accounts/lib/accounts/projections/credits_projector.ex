defmodule Accounts.Projections.CreditsProjector do
  @moduledoc """
  Projects credits to customer accounts into `credits` (README, D8). A settled credit keeps its
  row, with the way it settled, as a trail of the transfer saga.
  """

  use Commanded.Projections.Ecto,
    application: Accounts.App,
    repo: Accounts.Repo,
    name: "credits_projector"

  alias Accounts.Events.CreditAuthorized
  alias Accounts.Events.CreditCancelled
  alias Accounts.Events.CreditPosted
  alias Accounts.Events.CreditRejected
  alias Accounts.Projections.Credit

  project(%CreditAuthorized{} = event, metadata, fn multi ->
    credit = %{new_credit(event) | status: :authorized, authorized_at: metadata.created_at}
    Ecto.Multi.insert(multi, :credit, credit)
  end)

  project(%CreditRejected{} = event, metadata, fn multi ->
    credit = %{
      new_credit(event)
      | status: :rejected,
        reason: to_string(event.reason),
        settled_at: metadata.created_at
    }

    Ecto.Multi.insert(multi, :credit, credit)
  end)

  # README, D2: a credit from a settlement account is posted with no authorization first, so
  # the row may not exist yet. An authorized one keeps its authorized_at.
  project(%CreditPosted{} = event, metadata, fn multi ->
    credit = %{new_credit(event) | status: :posted, settled_at: metadata.created_at}

    Ecto.Multi.insert(multi, :credit, credit,
      conflict_target: [:account_id, :correlation_id],
      on_conflict: {:replace, [:status, :settled_at]}
    )
  end)

  project(%CreditCancelled{} = event, metadata, fn multi ->
    Ecto.Multi.update_all(
      multi,
      :credit,
      from(c in Credit,
        where: c.account_id == ^event.account_id and c.correlation_id == ^event.correlation_id
      ),
      set: [status: :cancelled, settled_at: metadata.created_at]
    )
  end)

  defp new_credit(event) do
    %Credit{
      account_id: event.account_id,
      correlation_id: event.correlation_id,
      amount: event.amount
    }
  end

  # `mix commanded.reset` calls this before replaying the event store from the origin (README,
  # D11): the read model and its version start empty.
  @impl Commanded.Event.Handler
  def before_reset do
    {:ok, _changes} =
      Ecto.Multi.new()
      |> Ecto.Multi.delete_all(:read_model, Credit)
      |> Ecto.Multi.delete_all(
        :projection_version,
        from(v in ProjectionVersion, where: v.projection_name == "credits_projector")
      )
      |> Accounts.Repo.transaction()

    :ok
  end
end
