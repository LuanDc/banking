defmodule Accounts.Projections.ReservationsProjector do
  @moduledoc """
  Projects balance reservations into `reservations` (README, section 7). A settled reservation
  keeps its row, with the way it settled, as a trail of the transfer saga.
  """

  use Commanded.Projections.Ecto,
    application: Accounts.App,
    repo: Accounts.Repo,
    name: "reservations_projector"

  alias Accounts.Events.BalanceReleased
  alias Accounts.Events.BalanceReservationRejected
  alias Accounts.Events.BalanceReserved
  alias Accounts.Events.ReservationConfirmed
  alias Accounts.Projections.Reservation

  project(%BalanceReserved{} = event, metadata, fn multi ->
    Ecto.Multi.insert(multi, :reservation, %Reservation{
      account_id: event.account_id,
      correlation_id: event.correlation_id,
      amount: event.amount,
      status: :open,
      reserved_at: metadata.created_at
    })
  end)

  project(%BalanceReservationRejected{} = event, metadata, fn multi ->
    Ecto.Multi.insert(multi, :reservation, %Reservation{
      account_id: event.account_id,
      correlation_id: event.correlation_id,
      amount: event.amount,
      status: :rejected,
      reason: to_string(event.reason),
      reserved_at: metadata.created_at
    })
  end)

  project(%ReservationConfirmed{} = event, metadata, fn multi ->
    settle(multi, event, metadata, :confirmed)
  end)

  project(%BalanceReleased{} = event, metadata, fn multi ->
    settle(multi, event, metadata, :released)
  end)

  defp settle(multi, event, metadata, status) do
    Ecto.Multi.update_all(
      multi,
      :reservation,
      from(r in Reservation,
        where: r.account_id == ^event.account_id and r.correlation_id == ^event.correlation_id
      ),
      set: [status: status, settled_at: metadata.created_at]
    )
  end

  # `mix commanded.reset` calls this before replaying the event store from the origin (README,
  # D11): the read model and its version start empty.
  @impl Commanded.Event.Handler
  def before_reset do
    {:ok, _changes} =
      Ecto.Multi.new()
      |> Ecto.Multi.delete_all(:read_model, Reservation)
      |> Ecto.Multi.delete_all(
        :projection_version,
        from(v in ProjectionVersion, where: v.projection_name == "reservations_projector")
      )
      |> Accounts.Repo.transaction()

    :ok
  end
end
