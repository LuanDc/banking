defmodule E2E.Stories.AccountLifecycleTest do
  use E2E.StoryCase, async: true

  test "opening a customer account opens its ledger account" do
    assert %{status: 201, body: %{"account_id" => account_id, "status" => "pending_kyc"}} =
             Accounts.open_account(new_key("customer"))

    # Accounts → RabbitMQ → Ledger: OpenLedgerAccount (docs, D5).
    eventually(fn ->
      assert %{status: 200, body: %{"status" => "open"}} = Ledger.ledger_account(account_id)
    end)

    assert %{status: 204} = Accounts.transition(account_id, "activate")

    eventually(fn ->
      assert %{status: 200, body: %{"data" => history}} = Accounts.status_history(account_id)

      assert Enum.map(history, & &1["event"]) ==
               ["CustomerAccountOpened", "CustomerAccountActivated"]
    end)
  end

  test "an account with money in it cannot close until it is emptied" do
    account_id = funded_account(300)
    other = active_account()

    assert %{status: 409, body: %{"errors" => %{"code" => "balance_not_zero"}}} =
             Accounts.transition(account_id, "close")

    key = new_key("transfer")
    assert %{status: 202} = Accounts.transfer(account_id, other, 300, key)
    settled_transfer(key, "completed")
    eventually(fn -> assert_balance(account_id, 0) end)

    assert %{status: 204} = Accounts.transition(account_id, "close")

    eventually(fn ->
      assert_status(account_id, "closed")
      assert %{status: 200, body: %{"status" => "closed"}} = Ledger.ledger_account(account_id)
    end)
  end

  test "a transition the FSM does not allow is refused" do
    %{status: 201, body: %{"account_id" => account_id}} =
      Accounts.open_account(new_key("customer"))

    assert %{status: 409, body: %{"errors" => %{"code" => "invalid_transition"}}} =
             Accounts.transition(account_id, "freeze", "suspected fraud")
  end
end
