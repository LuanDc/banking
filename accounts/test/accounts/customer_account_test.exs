defmodule Accounts.CustomerAccountTest do
  use ExUnit.Case, async: true

  alias Accounts.Commands.ActivateCustomerAccount
  alias Accounts.Commands.BlockCustomerAccount
  alias Accounts.Commands.CloseCustomerAccount
  alias Accounts.Commands.FreezeCustomerAccount
  alias Accounts.Commands.OpenCustomerAccount
  alias Accounts.Commands.ReserveBalance
  alias Accounts.Commands.UnblockCustomerAccount
  alias Accounts.Commands.UnfreezeCustomerAccount
  alias Accounts.CustomerAccount
  alias Accounts.Events.BalanceReservationRejected
  alias Accounts.Events.BalanceReserved
  alias Accounts.Events.CustomerAccountActivated
  alias Accounts.Events.CustomerAccountBlocked
  alias Accounts.Events.CustomerAccountClosed
  alias Accounts.Events.CustomerAccountFrozen
  alias Accounts.Events.CustomerAccountOpened
  alias Accounts.Events.CustomerAccountUnblocked
  alias Accounts.Events.CustomerAccountUnfrozen

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
  end

  describe "applying BalanceReservationRejected" do
    test "leaves the account unchanged" do
      account = active_account(1_000)

      event = %BalanceReservationRejected{
        account_id: "acc-1",
        amount: 1_001,
        correlation_id: "corr-1",
        reason: :insufficient_balance
      }

      assert CustomerAccount.apply(account, event) == account
    end
  end

  defp active_account(available_balance),
    do: %CustomerAccount{
      account_id: "acc-1",
      status: :active,
      available_balance: available_balance
    }

  defp reserve(account, amount) do
    command = %ReserveBalance{account_id: "acc-1", amount: amount, correlation_id: "corr-1"}
    CustomerAccount.execute(account, command)
  end
end
