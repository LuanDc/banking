defmodule Accounts.Projections.CreditsProjectorTest do
  # Not async: every test writes the same row of projection_versions.
  use Accounts.DataCase, async: false

  alias Accounts.Events.CreditAuthorized
  alias Accounts.Events.CreditCancelled
  alias Accounts.Events.CreditPosted
  alias Accounts.Events.CreditRejected
  alias Accounts.Projections.Credit
  alias Accounts.Projections.CreditsProjector

  @authorized_at ~U[2026-09-25 12:00:00.000000Z]
  @settled_at ~U[2026-09-25 12:00:05.000000Z]

  test "an authorized credit is projected as pending" do
    authorize()

    assert %Credit{
             account_id: "acc-1",
             correlation_id: "corr-1",
             amount: 400,
             status: :authorized,
             authorized_at: @authorized_at,
             settled_at: nil
           } = Repo.one(Credit)
  end

  test "a posted credit is settled as posted and keeps its authorization" do
    authorize()
    :ok = project(%CreditPosted{account_id: "acc-1", correlation_id: "corr-1", amount: 400}, 2)

    assert %Credit{status: :posted, authorized_at: @authorized_at, settled_at: @settled_at} =
             Repo.one(Credit)
  end

  # README, D2: money from a settlement account is posted with no authorization first.
  test "a credit posted with no authorization is recorded as posted" do
    :ok = project(%CreditPosted{account_id: "acc-1", correlation_id: "pix-1", amount: 700}, 1)

    assert %Credit{status: :posted, amount: 700, authorized_at: nil, settled_at: @settled_at} =
             Repo.one(Credit)
  end

  test "a cancelled credit is settled as cancelled" do
    authorize()
    :ok = project(%CreditCancelled{account_id: "acc-1", correlation_id: "corr-1", amount: 400}, 2)

    assert %Credit{status: :cancelled, settled_at: @settled_at} = Repo.one(Credit)
  end

  test "a rejected credit is recorded with its reason" do
    event = %CreditRejected{
      account_id: "acc-1",
      correlation_id: "corr-1",
      amount: 400,
      reason: :credit_not_allowed
    }

    :ok = project(event, 1, @authorized_at)

    assert %Credit{status: :rejected, reason: "credit_not_allowed"} = Repo.one(Credit)
  end

  # The aggregate decides AuthorizeCredit again when it is redelivered.
  test "an authorization repeated for the same correlation_id keeps one row" do
    authorize()
    event = %CreditAuthorized{account_id: "acc-1", correlation_id: "corr-1", amount: 400}
    :ok = project(event, 2, @settled_at)

    assert [%Credit{status: :authorized, authorized_at: @settled_at}] = Repo.all(Credit)
  end

  test "a redelivered event is projected only once" do
    authorize()
    authorize()

    assert Repo.aggregate(Credit, :count) == 1
  end

  test "a reset clears the read model, so the replay starts from scratch" do
    authorize()
    :ok = CreditsProjector.before_reset()

    assert Repo.all(Credit) == []

    authorize()

    assert [%Credit{status: :authorized}] = Repo.all(Credit)
  end

  defp authorize do
    event = %CreditAuthorized{account_id: "acc-1", correlation_id: "corr-1", amount: 400}
    :ok = project(event, 1, @authorized_at)
  end

  defp project(event, event_number, created_at \\ @settled_at) do
    CreditsProjector.handle(event, %{
      handler_name: "credits_projector",
      event_number: event_number,
      created_at: created_at
    })
  end
end
