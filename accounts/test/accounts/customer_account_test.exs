defmodule Accounts.CustomerAccountTest do
  use ExUnit.Case, async: true

  alias Accounts.Commands.ActivateCustomerAccount
  alias Accounts.Commands.AuthorizeCredit
  alias Accounts.Commands.BlockCustomerAccount
  alias Accounts.Commands.CancelCredit
  alias Accounts.Commands.CloseCustomerAccount
  alias Accounts.Commands.ConfirmReservation
  alias Accounts.Commands.FreezeCustomerAccount
  alias Accounts.Commands.OpenCustomerAccount
  alias Accounts.Commands.PostCredit
  alias Accounts.Commands.ReleaseBalance
  alias Accounts.Commands.ReserveBalance
  alias Accounts.Commands.UnblockCustomerAccount
  alias Accounts.Commands.UnfreezeCustomerAccount
  alias Accounts.CustomerAccount
  alias Accounts.Events.BalanceReleased
  alias Accounts.Events.BalanceReservationRejected
  alias Accounts.Events.BalanceReserved
  alias Accounts.Events.CreditAuthorized
  alias Accounts.Events.CreditCancelled
  alias Accounts.Events.CreditPosted
  alias Accounts.Events.CreditRejected
  alias Accounts.Events.CustomerAccountActivated
  alias Accounts.Events.CustomerAccountBlocked
  alias Accounts.Events.CustomerAccountClosed
  alias Accounts.Events.CustomerAccountFrozen
  alias Accounts.Events.CustomerAccountOpened
  alias Accounts.Events.CustomerAccountUnblocked
  alias Accounts.Events.CustomerAccountUnfrozen
  alias Accounts.Events.ReservationConfirmed

  describe "OpenCustomerAccount" do
    test "emits CustomerAccountOpened for a new account" do
      command = %OpenCustomerAccount{account_id: "acc-1", customer_id: "cus-1"}

      assert %CustomerAccountOpened{account_id: "acc-1", customer_id: "cus-1"} =
               CustomerAccount.execute(%CustomerAccount{}, command)
    end

    test "rejects an account that was already opened" do
      account = %CustomerAccount{account_id: "acc-1", status: :pending_kyc}
      command = %OpenCustomerAccount{account_id: "acc-1", customer_id: "cus-1"}

      assert {:error, :account_already_exists} = CustomerAccount.execute(account, command)
    end
  end

  describe "ActivateCustomerAccount" do
    test "emits CustomerAccountActivated for an account pending KYC" do
      account = %CustomerAccount{account_id: "acc-1", status: :pending_kyc}
      command = %ActivateCustomerAccount{account_id: "acc-1"}

      assert %CustomerAccountActivated{account_id: "acc-1"} =
               CustomerAccount.execute(account, command)
    end

    test "rejects an account that is not pending KYC" do
      account = %CustomerAccount{account_id: "acc-1", status: :active}
      command = %ActivateCustomerAccount{account_id: "acc-1"}

      assert {:error, :invalid_transition} = CustomerAccount.execute(account, command)
    end

    test "rejects a blocked account, which is only reactivated by unblocking" do
      account = %CustomerAccount{account_id: "acc-1", status: :blocked}
      command = %ActivateCustomerAccount{account_id: "acc-1"}

      assert {:error, :invalid_transition} = CustomerAccount.execute(account, command)
    end
  end

  describe "BlockCustomerAccount" do
    test "emits CustomerAccountBlocked for an active account" do
      account = %CustomerAccount{account_id: "acc-1", status: :active}
      command = %BlockCustomerAccount{account_id: "acc-1", reason: "suspected fraud"}

      assert %CustomerAccountBlocked{account_id: "acc-1", reason: "suspected fraud"} =
               CustomerAccount.execute(account, command)
    end

    test "rejects an account that is not active" do
      account = %CustomerAccount{account_id: "acc-1", status: :pending_kyc}
      command = %BlockCustomerAccount{account_id: "acc-1", reason: "suspected fraud"}

      assert {:error, :invalid_transition} = CustomerAccount.execute(account, command)
    end
  end

  describe "UnblockCustomerAccount" do
    test "emits CustomerAccountUnblocked for a blocked account" do
      account = %CustomerAccount{account_id: "acc-1", status: :blocked}
      command = %UnblockCustomerAccount{account_id: "acc-1"}

      assert %CustomerAccountUnblocked{account_id: "acc-1"} =
               CustomerAccount.execute(account, command)
    end

    test "rejects an account that is not blocked" do
      account = %CustomerAccount{account_id: "acc-1", status: :active}
      command = %UnblockCustomerAccount{account_id: "acc-1"}

      assert {:error, :invalid_transition} = CustomerAccount.execute(account, command)
    end
  end

  describe "FreezeCustomerAccount" do
    test "emits CustomerAccountFrozen for an active account" do
      account = %CustomerAccount{account_id: "acc-1", status: :active}
      command = %FreezeCustomerAccount{account_id: "acc-1", reason: "court order"}

      assert %CustomerAccountFrozen{account_id: "acc-1", reason: "court order"} =
               CustomerAccount.execute(account, command)
    end

    test "rejects a blocked account" do
      account = %CustomerAccount{account_id: "acc-1", status: :blocked}
      command = %FreezeCustomerAccount{account_id: "acc-1", reason: "court order"}

      assert {:error, :invalid_transition} = CustomerAccount.execute(account, command)
    end
  end

  describe "UnfreezeCustomerAccount" do
    test "emits CustomerAccountUnfrozen for a frozen account" do
      account = %CustomerAccount{account_id: "acc-1", status: :frozen}
      command = %UnfreezeCustomerAccount{account_id: "acc-1"}

      assert %CustomerAccountUnfrozen{account_id: "acc-1"} =
               CustomerAccount.execute(account, command)
    end

    test "rejects a blocked account, which is only reactivated by unblocking" do
      account = %CustomerAccount{account_id: "acc-1", status: :blocked}
      command = %UnfreezeCustomerAccount{account_id: "acc-1"}

      assert {:error, :invalid_transition} = CustomerAccount.execute(account, command)
    end
  end

  describe "CloseCustomerAccount" do
    test "emits CustomerAccountClosed for an active account" do
      account = %CustomerAccount{account_id: "acc-1", status: :active}
      command = %CloseCustomerAccount{account_id: "acc-1"}

      assert %CustomerAccountClosed{account_id: "acc-1"} =
               CustomerAccount.execute(account, command)
    end

    test "emits CustomerAccountClosed for a blocked account" do
      account = %CustomerAccount{account_id: "acc-1", status: :blocked}
      command = %CloseCustomerAccount{account_id: "acc-1"}

      assert %CustomerAccountClosed{account_id: "acc-1"} =
               CustomerAccount.execute(account, command)
    end

    test "rejects a frozen account" do
      account = %CustomerAccount{account_id: "acc-1", status: :frozen}
      command = %CloseCustomerAccount{account_id: "acc-1"}

      assert {:error, :invalid_transition} = CustomerAccount.execute(account, command)
    end

    test "rejects an account that still holds available balance (H6)" do
      command = %CloseCustomerAccount{account_id: "acc-1"}

      assert {:error, :balance_not_zero} = CustomerAccount.execute(active_account(1), command)
    end

    test "rejects an account with a reservation still open (H6)" do
      account = %CustomerAccount{active_account(0) | reservations: %{"corr-1" => 400}}
      command = %CloseCustomerAccount{account_id: "acc-1"}

      assert {:error, :open_reservations} = CustomerAccount.execute(account, command)
    end

    test "rejects an account with an authorized credit still on its way (H6)" do
      account = %CustomerAccount{active_account(0) | pending_credits: %{"corr-1" => 400}}
      command = %CloseCustomerAccount{account_id: "acc-1"}

      assert {:error, :pending_credits} = CustomerAccount.execute(account, command)
    end

    test "closed is terminal: no transition applies to a closed account" do
      account = %CustomerAccount{account_id: "acc-1", status: :closed}

      for command <- [
            %ActivateCustomerAccount{account_id: "acc-1"},
            %BlockCustomerAccount{account_id: "acc-1", reason: "suspected fraud"},
            %UnblockCustomerAccount{account_id: "acc-1"},
            %FreezeCustomerAccount{account_id: "acc-1", reason: "court order"},
            %UnfreezeCustomerAccount{account_id: "acc-1"},
            %CloseCustomerAccount{account_id: "acc-1"}
          ] do
        assert {:error, :invalid_transition} = CustomerAccount.execute(account, command)
      end
    end
  end

  describe "ReserveBalance" do
    test "emits BalanceReserved for an active account with enough available balance" do
      account = %CustomerAccount{account_id: "acc-1", status: :active, available_balance: 1_000}

      command = %ReserveBalance{account_id: "acc-1", amount: 400, correlation_id: "corr-1"}

      assert %BalanceReserved{account_id: "acc-1", amount: 400, correlation_id: "corr-1"} =
               CustomerAccount.execute(account, command)
    end

    test "emits BalanceReservationRejected when the available balance is not enough" do
      assert %BalanceReservationRejected{
               account_id: "acc-1",
               amount: 1_001,
               correlation_id: "corr-1",
               reason: :insufficient_balance
             } = reserve(active_account(1_000), 1_001)
    end

    test "reserves the whole available balance" do
      assert %BalanceReserved{amount: 1_000} = reserve(active_account(1_000), 1_000)
    end

    test "rejects a blocked account, which may receive money but not send it" do
      blocked = %CustomerAccount{active_account(1_000) | status: :blocked}

      assert %BalanceReservationRejected{reason: :account_not_active} = reserve(blocked, 400)
    end

    test "rejects a negative amount, which would raise the available balance" do
      assert %BalanceReservationRejected{reason: :invalid_amount} =
               reserve(active_account(1_000), -500)
    end

    test "rejects a zero amount, which holds no money" do
      assert %BalanceReservationRejected{reason: :invalid_amount} =
               reserve(active_account(1_000), 0)
    end

    test "rejects an amount that is not an integer number of cents" do
      assert %BalanceReservationRejected{reason: :invalid_amount} =
               reserve(active_account(1_000), 10.5)
    end

    test "ignores a repeated command for a reservation that is already open" do
      reserved = reserve(active_account(1_000), 400)
      account = CustomerAccount.apply(active_account(1_000), reserved)

      assert [] = reserve(account, 400)
    end

    test "ignores a repeated command for a reservation it already rejected" do
      rejection = reserve(active_account(100), 400)
      account = CustomerAccount.apply(active_account(100), rejection)

      # The balance arrived in the meantime: the saga was still decided, and stays rejected.
      account = %CustomerAccount{account | available_balance: 1_000}

      assert [] = reserve(account, 400)
    end

    test "ignores a repeated command for a reservation already settled" do
      reserved = reserve(active_account(1_000), 400)

      confirmed = %ReservationConfirmed{
        account_id: "acc-1",
        correlation_id: "corr-1",
        amount: 400
      }

      account =
        active_account(1_000)
        |> CustomerAccount.apply(reserved)
        |> CustomerAccount.apply(confirmed)

      assert [] = reserve(account, 400)
    end
  end

  describe "ConfirmReservation" do
    test "emits ReservationConfirmed for an open reservation" do
      command = %ConfirmReservation{account_id: "acc-1", correlation_id: "corr-1"}

      assert %ReservationConfirmed{account_id: "acc-1", correlation_id: "corr-1", amount: 400} =
               CustomerAccount.execute(with_reservation(), command)
    end

    test "confirms on a frozen account: a transfer in flight finishes (H5)" do
      frozen = %CustomerAccount{with_reservation() | status: :frozen}
      command = %ConfirmReservation{account_id: "acc-1", correlation_id: "corr-1"}

      assert %ReservationConfirmed{amount: 400} = CustomerAccount.execute(frozen, command)
    end

    test "ignores a reservation that is not open, e.g. one already confirmed" do
      command = %ConfirmReservation{account_id: "acc-1", correlation_id: "corr-9"}

      assert [] = CustomerAccount.execute(with_reservation(), command)
    end
  end

  describe "ReleaseBalance" do
    test "emits BalanceReleased for an open reservation" do
      command = %ReleaseBalance{account_id: "acc-1", correlation_id: "corr-1"}

      assert %BalanceReleased{account_id: "acc-1", correlation_id: "corr-1", amount: 400} =
               CustomerAccount.execute(with_reservation(), command)
    end

    test "releases on a frozen account: a transfer in flight finishes (H5)" do
      frozen = %CustomerAccount{with_reservation() | status: :frozen}
      command = %ReleaseBalance{account_id: "acc-1", correlation_id: "corr-1"}

      assert %BalanceReleased{amount: 400} = CustomerAccount.execute(frozen, command)
    end

    test "ignores a reservation that is not open, e.g. one already released" do
      command = %ReleaseBalance{account_id: "acc-1", correlation_id: "corr-9"}

      assert [] = CustomerAccount.execute(with_reservation(), command)
    end
  end

  describe "AuthorizeCredit" do
    test "emits CreditAuthorized for an active account" do
      assert %CreditAuthorized{account_id: "acc-1", amount: 400, correlation_id: "corr-1"} =
               authorize_credit(active_account(0), 400)
    end

    test "emits CreditAuthorized for a blocked account, which may receive money but not send it" do
      blocked = %CustomerAccount{active_account(0) | status: :blocked}

      assert %CreditAuthorized{amount: 400} = authorize_credit(blocked, 400)
    end

    test "emits CreditRejected for a frozen account" do
      frozen = %CustomerAccount{active_account(0) | status: :frozen}

      assert %CreditRejected{
               account_id: "acc-1",
               amount: 400,
               correlation_id: "corr-1",
               reason: :credit_not_allowed
             } = authorize_credit(frozen, 400)
    end

    test "emits CreditRejected for an account pending KYC or closed" do
      for status <- [:pending_kyc, :closed] do
        account = %CustomerAccount{active_account(0) | status: status}

        assert %CreditRejected{reason: :credit_not_allowed} = authorize_credit(account, 400)
      end
    end

    test "emits CreditRejected for a zero, negative or fractional amount" do
      for amount <- [0, -100, 10.5] do
        assert %CreditRejected{reason: :invalid_amount} =
                 authorize_credit(active_account(0), amount)
      end
    end

    test "ignores a repeated command for a credit it already rejected" do
      frozen = %CustomerAccount{active_account(0) | status: :frozen}
      account = CustomerAccount.apply(frozen, authorize_credit(frozen, 400))

      # The account was unfrozen in the meantime: the saga was still decided, and stays rejected.
      account = %CustomerAccount{account | status: :active}

      assert [] = authorize_credit(account, 400)
    end

    test "ignores a repeated command for a credit already authorized" do
      account = CustomerAccount.apply(active_account(0), authorize_credit(active_account(0), 400))

      assert [] = authorize_credit(account, 400)
    end

    test "ignores a repeated command for a credit already cancelled" do
      cancelled = %CreditCancelled{account_id: "acc-1", correlation_id: "corr-1", amount: 400}

      account =
        active_account(0)
        |> CustomerAccount.apply(authorize_credit(active_account(0), 400))
        |> CustomerAccount.apply(cancelled)

      assert [] = authorize_credit(account, 400)
    end
  end

  describe "PostCredit" do
    test "emits CreditPosted for a credit the Ledger booked" do
      assert %CreditPosted{account_id: "acc-1", amount: 400, correlation_id: "corr-1"} =
               post_credit(active_account(0), 400)
    end

    test "ignores a redelivered credit that was already posted" do
      account = %CustomerAccount{active_account(400) | posted_credits: MapSet.new(["corr-1"])}

      assert [] = post_credit(account, 400)
    end

    test "posts a booked credit whatever the status: it mirrors what the Ledger already booked (H5)" do
      frozen = %CustomerAccount{active_account(0) | status: :frozen}

      assert %CreditPosted{amount: 400} = post_credit(frozen, 400)
    end
  end

  describe "CancelCredit" do
    test "emits CreditCancelled for a pending credit whose batch the Ledger rejected" do
      account = %CustomerAccount{active_account(0) | pending_credits: %{"corr-1" => 400}}
      command = %CancelCredit{account_id: "acc-1", correlation_id: "corr-1"}

      assert %CreditCancelled{account_id: "acc-1", correlation_id: "corr-1", amount: 400} =
               CustomerAccount.execute(account, command)
    end

    test "ignores a credit that is not pending, e.g. one already cancelled" do
      command = %CancelCredit{account_id: "acc-1", correlation_id: "corr-1"}

      assert [] = CustomerAccount.execute(active_account(0), command)
    end
  end

  describe "applying CustomerAccountOpened" do
    test "moves the account to pending KYC" do
      event = %CustomerAccountOpened{account_id: "acc-1", customer_id: "cus-1"}

      assert %CustomerAccount{account_id: "acc-1", status: :pending_kyc} =
               CustomerAccount.apply(%CustomerAccount{}, event)
    end
  end

  describe "applying CustomerAccountActivated" do
    test "moves the account to active" do
      account = %CustomerAccount{account_id: "acc-1", status: :pending_kyc}
      event = %CustomerAccountActivated{account_id: "acc-1"}

      assert %CustomerAccount{account_id: "acc-1", status: :active} =
               CustomerAccount.apply(account, event)
    end
  end

  describe "applying CustomerAccountBlocked" do
    test "moves the account to blocked" do
      account = %CustomerAccount{account_id: "acc-1", status: :active}
      event = %CustomerAccountBlocked{account_id: "acc-1", reason: "suspected fraud"}

      assert %CustomerAccount{account_id: "acc-1", status: :blocked} =
               CustomerAccount.apply(account, event)
    end
  end

  describe "applying CustomerAccountUnblocked" do
    test "moves the account back to active" do
      account = %CustomerAccount{account_id: "acc-1", status: :blocked}
      event = %CustomerAccountUnblocked{account_id: "acc-1"}

      assert %CustomerAccount{account_id: "acc-1", status: :active} =
               CustomerAccount.apply(account, event)
    end
  end

  describe "applying CustomerAccountFrozen" do
    test "moves the account to frozen" do
      account = %CustomerAccount{account_id: "acc-1", status: :active}
      event = %CustomerAccountFrozen{account_id: "acc-1", reason: "court order"}

      assert %CustomerAccount{account_id: "acc-1", status: :frozen} =
               CustomerAccount.apply(account, event)
    end
  end

  describe "applying CustomerAccountUnfrozen" do
    test "moves the account back to active" do
      account = %CustomerAccount{account_id: "acc-1", status: :frozen}
      event = %CustomerAccountUnfrozen{account_id: "acc-1"}

      assert %CustomerAccount{account_id: "acc-1", status: :active} =
               CustomerAccount.apply(account, event)
    end
  end

  describe "applying CustomerAccountClosed" do
    test "moves the account to closed" do
      account = %CustomerAccount{account_id: "acc-1", status: :active}
      event = %CustomerAccountClosed{account_id: "acc-1"}

      assert %CustomerAccount{account_id: "acc-1", status: :closed} =
               CustomerAccount.apply(account, event)
    end
  end

  describe "applying BalanceReserved" do
    test "holds the amount out of the available balance" do
      event = %BalanceReserved{account_id: "acc-1", amount: 400, correlation_id: "corr-1"}

      assert %CustomerAccount{available_balance: 600} =
               CustomerAccount.apply(active_account(1_000), event)
    end

    test "records the reservation under its correlation id" do
      event = %BalanceReserved{account_id: "acc-1", amount: 400, correlation_id: "corr-1"}

      assert %CustomerAccount{reservations: %{"corr-1" => 400}} =
               CustomerAccount.apply(active_account(1_000), event)
    end
  end

  describe "applying BalanceReservationRejected" do
    test "holds no balance, but remembers the rejection" do
      event = %BalanceReservationRejected{
        account_id: "acc-1",
        amount: 1_001,
        correlation_id: "corr-1",
        reason: :insufficient_balance
      }

      assert %CustomerAccount{available_balance: 1_000, reservations: reservations} =
               account = CustomerAccount.apply(active_account(1_000), event)

      assert reservations == %{}
      assert MapSet.member?(account.decided_reservations, "corr-1")
    end
  end

  describe "applying ReservationConfirmed" do
    test "settles the reservation, leaving the available balance as it was" do
      event = %ReservationConfirmed{account_id: "acc-1", correlation_id: "corr-1", amount: 400}

      assert %CustomerAccount{available_balance: 600, reservations: reservations} =
               CustomerAccount.apply(with_reservation(), event)

      assert reservations == %{}
    end
  end

  describe "applying BalanceReleased" do
    test "gives the reserved amount back to the available balance" do
      event = %BalanceReleased{account_id: "acc-1", correlation_id: "corr-1", amount: 400}

      assert %CustomerAccount{available_balance: 1_000, reservations: reservations} =
               CustomerAccount.apply(with_reservation(), event)

      assert reservations == %{}
    end
  end

  describe "applying CreditAuthorized" do
    test "records the credit as pending until the Ledger books it" do
      event = %CreditAuthorized{account_id: "acc-1", amount: 400, correlation_id: "corr-1"}

      assert %CustomerAccount{available_balance: 1_000, pending_credits: %{"corr-1" => 400}} =
               CustomerAccount.apply(active_account(1_000), event)
    end
  end

  describe "applying CreditRejected" do
    test "holds no pending credit, but remembers the rejection" do
      event = %CreditRejected{
        account_id: "acc-1",
        amount: 400,
        correlation_id: "corr-1",
        reason: :credit_not_allowed
      }

      assert %CustomerAccount{available_balance: 1_000, pending_credits: pending} =
               account = CustomerAccount.apply(active_account(1_000), event)

      assert pending == %{}
      assert MapSet.member?(account.decided_credits, "corr-1")
    end
  end

  describe "applying CreditPosted" do
    test "adds the amount to the available balance" do
      event = %CreditPosted{account_id: "acc-1", amount: 400, correlation_id: "corr-1"}

      assert %CustomerAccount{available_balance: 1_400} =
               CustomerAccount.apply(active_account(1_000), event)
    end

    test "remembers the correlation id, so the credit is not posted twice" do
      event = %CreditPosted{account_id: "acc-1", amount: 400, correlation_id: "corr-1"}

      assert %CustomerAccount{posted_credits: posted_credits} =
               CustomerAccount.apply(active_account(1_000), event)

      assert MapSet.member?(posted_credits, "corr-1")
    end

    test "clears the pending credit it settles" do
      account = %CustomerAccount{active_account(1_000) | pending_credits: %{"corr-1" => 400}}
      event = %CreditPosted{account_id: "acc-1", amount: 400, correlation_id: "corr-1"}

      assert %CustomerAccount{pending_credits: pending_credits} =
               CustomerAccount.apply(account, event)

      assert pending_credits == %{}
    end
  end

  describe "applying CreditCancelled" do
    test "drops the pending credit, leaving the available balance as it was" do
      account = %CustomerAccount{active_account(1_000) | pending_credits: %{"corr-1" => 400}}
      event = %CreditCancelled{account_id: "acc-1", correlation_id: "corr-1", amount: 400}

      assert %CustomerAccount{available_balance: 1_000, pending_credits: pending_credits} =
               CustomerAccount.apply(account, event)

      assert pending_credits == %{}
    end
  end

  defp active_account(available_balance),
    do: %CustomerAccount{
      account_id: "acc-1",
      status: :active,
      available_balance: available_balance
    }

  defp with_reservation,
    do: %CustomerAccount{active_account(600) | reservations: %{"corr-1" => 400}}

  defp authorize_credit(account, amount) do
    command = %AuthorizeCredit{account_id: "acc-1", amount: amount, correlation_id: "corr-1"}
    CustomerAccount.execute(account, command)
  end

  defp post_credit(account, amount) do
    command = %PostCredit{account_id: "acc-1", amount: amount, correlation_id: "corr-1"}
    CustomerAccount.execute(account, command)
  end

  defp reserve(account, amount) do
    command = %ReserveBalance{account_id: "acc-1", amount: amount, correlation_id: "corr-1"}
    CustomerAccount.execute(account, command)
  end
end
