defmodule Ledger.Accounts.CustomerAccountTest do
  use ExUnit.Case, async: true

  alias Ledger.Accounts.Commands.OpenCustomerAccount
  alias Ledger.Accounts.CustomerAccount
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

  describe "applying CustomerAccountOpened" do
    test "moves the account to pending KYC" do
      event = %CustomerAccountOpened{account_id: "acc-1", customer_id: "cus-1"}

      assert %CustomerAccount{account_id: "acc-1", status: :pending_kyc} =
               CustomerAccount.apply(%CustomerAccount{}, event)
    end
  end
end
