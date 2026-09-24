defmodule Accounts.CustomerAccountTest do
  use ExUnit.Case, async: true

  alias Accounts.Commands.ActivateCustomerAccount
  alias Accounts.Commands.BlockCustomerAccount
  alias Accounts.Commands.FreezeCustomerAccount
  alias Accounts.Commands.OpenCustomerAccount
  alias Accounts.Commands.UnblockCustomerAccount
  alias Accounts.CustomerAccount
  alias Accounts.Events.CustomerAccountActivated
  alias Accounts.Events.CustomerAccountBlocked
  alias Accounts.Events.CustomerAccountFrozen
  alias Accounts.Events.CustomerAccountOpened
  alias Accounts.Events.CustomerAccountUnblocked

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
end
