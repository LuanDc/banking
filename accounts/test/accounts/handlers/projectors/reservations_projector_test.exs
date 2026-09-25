defmodule Accounts.Handlers.Projectors.ReservationsProjectorTest do
  # Not async: every test writes the same row of projection_versions.
  use Accounts.DataCase, async: false

  alias Accounts.Events.BalanceReleased
  alias Accounts.Events.BalanceReservationRejected
  alias Accounts.Events.BalanceReserved
  alias Accounts.Events.ReservationConfirmed
  alias Accounts.Handlers.Projectors.ReservationsProjector
  alias Accounts.Projections.Reservation

  @reserved_at ~U[2026-09-25 12:00:00.000000Z]
  @settled_at ~U[2026-09-25 12:00:05.000000Z]

  test "a reservation is projected as open" do
    reserve()

    assert %Reservation{
             account_id: "acc-1",
             correlation_id: "corr-1",
             to_account_id: "acc-2",
             amount: 400,
             status: :open,
             reserved_at: @reserved_at,
             settled_at: nil
           } = Repo.one(Reservation)
  end

  test "a confirmed reservation is settled as confirmed" do
    reserve()

    :ok =
      project(
        %ReservationConfirmed{account_id: "acc-1", correlation_id: "corr-1", amount: 400},
        2
      )

    assert %Reservation{status: :confirmed, settled_at: @settled_at} = Repo.one(Reservation)
  end

  test "a released reservation is settled as released" do
    reserve()
    :ok = project(%BalanceReleased{account_id: "acc-1", correlation_id: "corr-1", amount: 400}, 2)

    assert %Reservation{status: :released, settled_at: @settled_at} = Repo.one(Reservation)
  end

  test "a rejected reservation is recorded with its reason" do
    :ok = project(rejected(), 1, @reserved_at)

    assert %Reservation{
             status: :rejected,
             reason: "insufficient_balance",
             to_account_id: "acc-2",
             settled_at: nil
           } = Repo.one(Reservation)
  end

  test "a redelivered reservation is projected only once" do
    reserve()
    reserve()

    assert Repo.aggregate(Reservation, :count) == 1
  end

  test "a reset clears the read model, so the replay starts from scratch" do
    reserve()
    :ok = ReservationsProjector.before_reset()

    assert Repo.all(Reservation) == []

    reserve()

    assert [%Reservation{status: :open}] = Repo.all(Reservation)
  end

  defp rejected do
    %BalanceReservationRejected{
      account_id: "acc-1",
      correlation_id: "corr-1",
      amount: 400,
      reason: :insufficient_balance,
      to_account_id: "acc-2"
    }
  end

  defp reserve do
    event = %BalanceReserved{
      account_id: "acc-1",
      correlation_id: "corr-1",
      amount: 400,
      to_account_id: "acc-2"
    }

    :ok = project(event, 1, @reserved_at)
  end

  defp project(event, event_number, created_at \\ @settled_at) do
    ReservationsProjector.handle(event, %{
      handler_name: "reservations_projector",
      event_number: event_number,
      created_at: created_at
    })
  end
end
