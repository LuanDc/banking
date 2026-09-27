defmodule E2E.Stories.DepositTest do
  use E2E.StoryCase, async: true

  test "an inbound PIX lands in both books" do
    account_id = active_account()

    assert %{status: 202} = Accounts.deposit(account_id, 1_000, new_key("deposit"))

    # Authorized in Accounts, booked in the Ledger, posted back to Accounts (docs, D13).
    eventually(fn -> assert_balance(account_id, 1_000) end)

    assert %{status: 200, body: %{"data" => [%{"status" => "posted", "amount" => 1_000}]}} =
             Accounts.credits(account_id)
  end

  test "a repeated Idempotency-Key credits the money once" do
    account_id = active_account()
    key = new_key("deposit")

    assert %{status: 202} = Accounts.deposit(account_id, 1_000, key)
    assert %{status: 202} = Accounts.deposit(account_id, 1_000, key)

    # A later deposit travels the same queues, so once it lands the repeat was handled too.
    assert %{status: 202} = Accounts.deposit(account_id, 1, new_key("sentinel"))
    eventually(fn -> assert_balance(account_id, 1_001) end)
  end

  test "a frozen account refuses a PIX" do
    account_id = active_account()
    assert %{status: 204} = Accounts.transition(account_id, "freeze", "court order")

    assert %{status: 422, body: %{"errors" => %{"code" => "credit_not_allowed"}}} =
             Accounts.deposit(account_id, 1_000, new_key("deposit"))
  end
end
