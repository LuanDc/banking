defmodule Accounts.Handlers.LedgerRouterTest do
  use ExUnit.Case, async: true

  alias Accounts.BankAccounts
  alias Accounts.Commands.AuthorizeCredit
  alias Accounts.Commands.ReleaseBalance
  alias Accounts.Events.BalanceReserved
  alias Accounts.Events.CreditAuthorized
  alias Accounts.Events.CreditRejected
  alias Accounts.Handlers.LedgerRouter
  alias Commanded.Event.FailureContext

  describe "commands_for/1" do
    test "asks the destination to authorize the credit once the source reserved the amount" do
      event = %BalanceReserved{
        account_id: "acc-1",
        amount: 400,
        transfer_id: "corr-1",
        to_account_id: "acc-2"
      }

      assert LedgerRouter.commands_for(event) == [
               %AuthorizeCredit{
                 account_id: "acc-2",
                 amount: 400,
                 transfer_id: "corr-1",
                 from_account_id: "acc-1"
               }
             ]
    end

    test "releases the source's reservation when the destination rejects the credit" do
      event = %CreditRejected{
        account_id: "acc-2",
        amount: 400,
        transfer_id: "corr-1",
        reason: :credit_not_allowed,
        from_account_id: "acc-1"
      }

      assert LedgerRouter.commands_for(event) == [
               %ReleaseBalance{account_id: "acc-1", transfer_id: "corr-1"}
             ]
    end

    test "releases nothing for a credit from a bank account, which holds no reservation" do
      event = %CreditRejected{
        account_id: "acc-2",
        amount: 400,
        transfer_id: "corr-1",
        reason: :credit_not_allowed,
        from_account_id: BankAccounts.pix_settlement()
      }

      assert LedgerRouter.commands_for(event) == []
    end

    test "releases a reservation that names no destination, which no saga can finish (D6)" do
      # Recorded before reservations carried their destination.
      event = %BalanceReserved{account_id: "acc-1", amount: 400, transfer_id: "corr-1"}

      assert LedgerRouter.commands_for(event) == [
               %ReleaseBalance{account_id: "acc-1", transfer_id: "corr-1"}
             ]
    end

    test "releases nothing for a rejected credit that names no source" do
      # Recorded before credits carried their source.
      event = %CreditRejected{
        account_id: "acc-2",
        transfer_id: "corr-1",
        reason: :invalid_amount
      }

      assert LedgerRouter.commands_for(event) == []
    end

    test "leaves a credit authorization to the outbox, which books it in the Ledger" do
      assert LedgerRouter.commands_for(%CreditAuthorized{}) == []
    end
  end

  test "retries a failed dispatch with a growing, capped delay, so the saga never stalls" do
    event = %BalanceReserved{}

    assert {:retry, first_delay, failure_context} =
             LedgerRouter.error({:error, :timeout}, event, %FailureContext{context: %{}})

    assert {:retry, second_delay, _failure_context} =
             LedgerRouter.error({:error, :timeout}, event, failure_context)

    assert second_delay > first_delay

    assert {:retry, capped, _failure_context} =
             LedgerRouter.error({:error, :timeout}, event, %FailureContext{
               context: %{failures: 1_000}
             })

    assert capped == :timer.minutes(5)
  end
end
