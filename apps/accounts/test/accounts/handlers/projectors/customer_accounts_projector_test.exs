defmodule Accounts.Handlers.Projectors.CustomerAccountsProjectorTest do
  # Not async: every test writes the same row of projection_versions.
  use Accounts.DataCase, async: false

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
  alias Accounts.Handlers.Projectors.CustomerAccountsProjector
  alias Accounts.Projections.CustomerAccount
  alias Accounts.Projections.StatusChange

  @opened_at ~U[2026-09-25 12:00:00.000000Z]
  @changed_at ~U[2026-09-26 12:00:00.000000Z]

  describe "CustomerAccountOpened" do
    test "projects the account as pending KYC" do
      open_account()

      assert %CustomerAccount{
               customer_id: "cus-1",
               status: :pending_kyc,
               status_reason: nil,
               available_balance: 0,
               opened_at: @opened_at,
               updated_at: @opened_at,
               closed_at: nil
             } = Repo.get(CustomerAccount, "acc-1")
    end

    test "records the first status change" do
      open_account()

      assert [
               %StatusChange{
                 account_id: "acc-1",
                 event: "CustomerAccountOpened",
                 status: :pending_kyc,
                 occurred_at: @opened_at
               }
             ] = Repo.all(StatusChange)
    end

    test "is projected only once when redelivered" do
      open_account()
      open_account()

      assert Repo.aggregate(StatusChange, :count) == 1
    end
  end

  test "an activated account becomes active" do
    open_account()
    :ok = project(%CustomerAccountActivated{account_id: "acc-1"}, 2)

    assert %CustomerAccount{status: :active, updated_at: @changed_at} =
             Repo.get(CustomerAccount, "acc-1")
  end

  test "a blocked account keeps the reason" do
    open_account()
    :ok = project(%CustomerAccountBlocked{account_id: "acc-1", reason: "suspected fraud"}, 2)

    assert %CustomerAccount{status: :blocked, status_reason: "suspected fraud"} =
             Repo.get(CustomerAccount, "acc-1")
  end

  test "an unblocked account becomes active and drops the reason" do
    open_account()
    :ok = project(%CustomerAccountBlocked{account_id: "acc-1", reason: "suspected fraud"}, 2)
    :ok = project(%CustomerAccountUnblocked{account_id: "acc-1"}, 3)

    assert %CustomerAccount{status: :active, status_reason: nil} =
             Repo.get(CustomerAccount, "acc-1")
  end

  test "a frozen account keeps the reason" do
    open_account()
    :ok = project(%CustomerAccountFrozen{account_id: "acc-1", reason: "court order"}, 2)

    assert %CustomerAccount{status: :frozen, status_reason: "court order"} =
             Repo.get(CustomerAccount, "acc-1")
  end

  test "an unfrozen account becomes active and drops the reason" do
    open_account()
    :ok = project(%CustomerAccountFrozen{account_id: "acc-1", reason: "court order"}, 2)
    :ok = project(%CustomerAccountUnfrozen{account_id: "acc-1"}, 3)

    assert %CustomerAccount{status: :active, status_reason: nil} =
             Repo.get(CustomerAccount, "acc-1")
  end

  test "a closed account records when it closed" do
    open_account()
    :ok = project(%CustomerAccountClosed{account_id: "acc-1"}, 2)

    assert %CustomerAccount{status: :closed, closed_at: @changed_at} =
             Repo.get(CustomerAccount, "acc-1")
  end

  test "the history keeps every status change with its reason" do
    open_account()
    :ok = project(%CustomerAccountActivated{account_id: "acc-1"}, 2)
    :ok = project(%CustomerAccountBlocked{account_id: "acc-1", reason: "suspected fraud"}, 3)

    assert [
             %StatusChange{event: "CustomerAccountOpened", status: :pending_kyc},
             %StatusChange{event: "CustomerAccountActivated", status: :active},
             %StatusChange{
               event: "CustomerAccountBlocked",
               status: :blocked,
               reason: "suspected fraud",
               occurred_at: @changed_at
             }
           ] = Repo.all(from c in StatusChange, order_by: c.id)
  end

  describe "available balance" do
    test "a posted credit raises it" do
      open_account()
      :ok = project(%CreditPosted{account_id: "acc-1", amount: 1_000, correlation_id: "c-1"}, 2)

      assert %CustomerAccount{available_balance: 1_000} = Repo.get(CustomerAccount, "acc-1")
    end

    test "a reservation holds it" do
      open_account()
      :ok = project(%CreditPosted{account_id: "acc-1", amount: 1_000, correlation_id: "c-1"}, 2)
      :ok = project(%BalanceReserved{account_id: "acc-1", amount: 400, correlation_id: "c-2"}, 3)

      assert %CustomerAccount{available_balance: 600} = Repo.get(CustomerAccount, "acc-1")
    end

    test "a released reservation gives it back" do
      open_account()
      :ok = project(%CreditPosted{account_id: "acc-1", amount: 1_000, correlation_id: "c-1"}, 2)
      :ok = project(%BalanceReserved{account_id: "acc-1", amount: 400, correlation_id: "c-2"}, 3)
      :ok = project(%BalanceReleased{account_id: "acc-1", amount: 400, correlation_id: "c-2"}, 4)

      assert %CustomerAccount{available_balance: 1_000} = Repo.get(CustomerAccount, "acc-1")
    end
  end

  test "a reset clears the read model, so the replay starts from scratch" do
    open_account()
    :ok = CustomerAccountsProjector.before_reset()

    assert Repo.all(CustomerAccount) == []
    assert Repo.all(StatusChange) == []

    open_account()

    assert [%CustomerAccount{account_id: "acc-1"}] = Repo.all(CustomerAccount)
  end

  defp open_account do
    :ok =
      project(%CustomerAccountOpened{account_id: "acc-1", customer_id: "cus-1"}, 1, @opened_at)
  end

  defp project(event, event_number, created_at \\ @changed_at) do
    CustomerAccountsProjector.handle(event, %{
      handler_name: "customer_accounts_projector",
      event_number: event_number,
      created_at: created_at
    })
  end
end
