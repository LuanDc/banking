defmodule Ledger.Aggregates.LedgerAccountTest do
  use ExUnit.Case, async: true

  alias Ledger.Aggregates.LedgerAccount
  alias Ledger.Commands.CloseLedgerAccount
  alias Ledger.Commands.OpenLedgerAccount
  alias Ledger.Events.LedgerAccountClosed
  alias Ledger.Events.LedgerAccountOpened

  describe "OpenLedgerAccount" do
    test "emits LedgerAccountOpened for a new account" do
      assert %LedgerAccountOpened{account_id: "acc-1"} =
               LedgerAccount.execute(%LedgerAccount{}, %OpenLedgerAccount{account_id: "acc-1"})
    end

    test "ignores a redelivered command for an account that already exists" do
      account = %LedgerAccount{account_id: "acc-1", status: :open}

      assert [] = LedgerAccount.execute(account, %OpenLedgerAccount{account_id: "acc-1"})
    end

    test "does not reopen a closed account: closing is terminal" do
      account = %LedgerAccount{account_id: "acc-1", status: :closed}

      assert [] = LedgerAccount.execute(account, %OpenLedgerAccount{account_id: "acc-1"})
    end
  end

  describe "CloseLedgerAccount" do
    test "emits LedgerAccountClosed for an open account" do
      account = %LedgerAccount{account_id: "acc-1", status: :open}

      assert %LedgerAccountClosed{account_id: "acc-1"} =
               LedgerAccount.execute(account, %CloseLedgerAccount{account_id: "acc-1"})
    end

    test "ignores a redelivered command for an account that is already closed" do
      account = %LedgerAccount{account_id: "acc-1", status: :closed}

      assert [] = LedgerAccount.execute(account, %CloseLedgerAccount{account_id: "acc-1"})
    end

    test "rejects an account that was never opened" do
      assert {:error, :account_not_found} =
               LedgerAccount.execute(%LedgerAccount{}, %CloseLedgerAccount{account_id: "acc-1"})
    end
  end

  describe "applying LedgerAccountOpened" do
    test "marks the account as open" do
      assert %LedgerAccount{account_id: "acc-1", status: :open} =
               LedgerAccount.apply(%LedgerAccount{}, %LedgerAccountOpened{account_id: "acc-1"})
    end
  end

  describe "applying LedgerAccountClosed" do
    test "marks the account as closed" do
      account = %LedgerAccount{account_id: "acc-1", status: :open}

      assert %LedgerAccount{account_id: "acc-1", status: :closed} =
               LedgerAccount.apply(account, %LedgerAccountClosed{account_id: "acc-1"})
    end
  end

  describe "lifespan" do
    test "leaves memory after 5 minutes without a command, once an event is stored" do
      assert LedgerAccount.after_event(%LedgerAccountOpened{}) == :timer.minutes(5)
    end

    test "leaves memory after 5 minutes without a command, after one that stored nothing" do
      assert LedgerAccount.after_command(%OpenLedgerAccount{}) == :timer.minutes(5)
    end

    test "leaves memory after 5 minutes without a command, after an error" do
      assert LedgerAccount.after_error(:any_reason) == :timer.minutes(5)
    end
  end
end
