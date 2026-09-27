defmodule E2E.Stories.TransferTest do
  use E2E.StoryCase, async: true

  test "a transfer moves money between two customers, in both books" do
    from = funded_account(1_000)
    to = active_account()
    key = new_key("transfer")

    assert %{status: 202, body: %{"status" => "pending", "transfer_id" => transfer_id}} =
             Accounts.transfer(from, to, 400, key)

    # The transfer has an id of its own; the key only answers a retry (docs, D17).
    assert transfer_id != key

    settled_transfer(transfer_id, "completed")

    eventually(fn ->
      assert_balance(from, 600)
      assert_balance(to, 400)
    end)

    # The settlement batch has an id of its own and names the transfer it settles (docs, D17).
    assert %{
             status: 200,
             body: %{"data" => [%{"transfer_id" => ^transfer_id, "entries" => entries}]}
           } = Ledger.batches(transfer_id)

    assert [
             %{"account_id" => ^from, "type" => "debit", "amount" => 400},
             %{"account_id" => ^to, "type" => "credit", "amount" => 400}
           ] = Enum.sort_by(entries, & &1["position"])
  end

  test "a blocked account still receives a transfer" do
    from = funded_account(1_000)
    to = active_account()
    assert %{status: 204} = Accounts.transition(to, "block", "suspected fraud")

    assert %{status: 202, body: %{"transfer_id" => transfer_id}} =
             Accounts.transfer(from, to, 250, new_key("transfer"))

    settled_transfer(transfer_id, "completed")
    eventually(fn -> assert_balance(to, 250) end)
  end

  test "a frozen destination refuses the credit and the saga gives the money back" do
    from = funded_account(1_000)
    to = active_account()
    assert %{status: 204} = Accounts.transition(to, "freeze", "court order")

    assert %{status: 202, body: %{"transfer_id" => transfer_id}} =
             Accounts.transfer(from, to, 400, new_key("transfer"))

    assert %{"reason" => "credit_not_allowed"} = settled_transfer(transfer_id, "failed")

    eventually(fn ->
      assert_balance(from, 1_000)
      assert_balance(to, 0)

      assert %{status: 200, body: %{"data" => [%{"status" => "released"}]}} =
               Accounts.reservations(from)
    end)

    assert %{status: 200, body: %{"data" => []}} = Ledger.batches(transfer_id)
  end

  test "a transfer above the available balance is refused at once" do
    from = funded_account(100)
    to = active_account()

    assert %{status: 422, body: %{"errors" => %{"code" => "insufficient_balance"}}} =
             Accounts.transfer(from, to, 101, new_key("transfer"))

    # The refusal is recorded: the source's reservation shows it (docs, D14).
    eventually(fn ->
      assert %{
               status: 200,
               body: %{"data" => [%{"status" => "rejected", "reason" => "insufficient_balance"}]}
             } = Accounts.reservations(from)
    end)

    assert_balance(from, 100)
  end

  test "a blocked account cannot send" do
    from = funded_account(1_000)
    to = active_account()
    assert %{status: 204} = Accounts.transition(from, "block", "suspected fraud")

    assert %{status: 422, body: %{"errors" => %{"code" => "account_not_active"}}} =
             Accounts.transfer(from, to, 100, new_key("transfer"))
  end

  test "a repeated Idempotency-Key starts no second transfer" do
    from = funded_account(1_000)
    to = active_account()
    key = new_key("transfer")

    assert %{status: 202, body: %{"transfer_id" => transfer_id}} =
             Accounts.transfer(from, to, 400, key)

    assert %{status: 202, body: %{"transfer_id" => ^transfer_id}} =
             Accounts.transfer(from, to, 400, key)

    settled_transfer(transfer_id, "completed")
    eventually(fn -> assert_balance(from, 600) end)
    assert_balance(to, 400)
  end

  test "an invalid transfer is refused before it reaches any account" do
    from = funded_account(1_000)

    assert %{
             status: 422,
             body: %{"errors" => %{"code" => "validation_failed", "fields" => fields}}
           } = Accounts.transfer(from, from, 0, new_key("transfer"))

    assert Map.keys(fields) |> Enum.sort() == ["amount", "to_account_id"]
  end
end
