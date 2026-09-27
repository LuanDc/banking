defmodule E2E.Stories.RedeliveryTest do
  # Delivery is at least once (docs, D3): each story replays a message that was already handled
  # and checks that no money moves twice (D4).
  #
  # Both consumers take one message at a time, in order (D10). A sentinel deposit published
  # after the replay goes through the same queues, so once it lands, the replay was handled.
  use E2E.StoryCase, async: true

  setup do
    from = funded_account(1_000)
    to = active_account()
    key = new_key("transfer")

    %{status: 202} = Accounts.transfer(from, to, 400, key)
    settled_transfer(key, "completed")
    eventually(fn -> assert_balance(to, 400) end)

    # The batch that settled it, to replay the very messages that booked it (docs, D17).
    batch_id =
      eventually(fn ->
        assert %{status: 200, body: %{"data" => [%{"batch_id" => batch_id}]}} =
                 Ledger.batches(key)

        batch_id
      end)

    entries = [
      %{account_id: from, type: "debit", amount: 400},
      %{account_id: to, type: "credit", amount: 400}
    ]

    %{from: from, to: to, key: key, batch_id: batch_id, entries: entries}
  end

  test "a redelivered BookTransactionBatch books nothing twice", context do
    Broker.publish_command("BookTransactionBatch", %{
      batch_id: context.batch_id,
      transfer_id: context.key,
      entries: context.entries
    })

    wait_for_sentinel()

    assert_balance(context.from, 600)
    assert_balance(context.to, 400)
  end

  test "a redelivered LedgerBatchBooked settles nothing twice", context do
    Broker.publish_event("LedgerBatchBooked", "ledger.batch.booked", %{
      batch_id: context.batch_id,
      transfer_id: context.key,
      entries: context.entries
    })

    wait_for_sentinel()

    assert_balance(context.from, 600)
    assert_balance(context.to, 400)
  end

  test "a late LedgerBatchRejected for a booked batch gives nothing back", context do
    Broker.publish_event("LedgerBatchRejected", "ledger.batch.rejected", %{
      batch_id: context.batch_id,
      transfer_id: context.key,
      reason: "unbalanced",
      entries: context.entries
    })

    wait_for_sentinel()

    assert_balance(context.from, 600)
    assert_balance(context.to, 400)
  end

  defp wait_for_sentinel do
    sentinel = active_account()
    %{status: 202} = Accounts.deposit(sentinel, 1, new_key("sentinel"))
    eventually(fn -> assert_balance(sentinel, 1) end)
  end
end
