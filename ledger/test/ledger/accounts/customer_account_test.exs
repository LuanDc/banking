defmodule Ledger.Accounts.CustomerAccountTest do
  use ExUnit.Case, async: true

  alias Ledger.Accounts.Commands.ActivateCustomerAccount
  alias Ledger.Accounts.Commands.OpenCustomerAccount
  alias Ledger.Accounts.CustomerAccount
  alias Ledger.Accounts.Events.CustomerAccountActivated
  alias Ledger.Accounts.Events.CustomerAccountOpened

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
end
