defmodule E2E.Stories.BooksBalanceTest do
  use E2E.StoryCase, async: true

  test "the books balance after every story: total debits equal total credits" do
    from = funded_account(500)
    to = active_account()
    key = new_key("transfer")

    %{status: 202, body: %{"transfer_id" => transfer_id}} = Accounts.transfer(from, to, 200, key)
    settled_transfer(transfer_id, "completed")

    # Every batch books its debits and credits together (docs, section 4.1), so the trial
    # balance holds at any moment, whatever other stories are doing.
    assert %{status: 200, body: %{"balanced" => true} = trial_balance} = Ledger.trial_balance()
    assert trial_balance["debit_total"] == trial_balance["credit_total"]
  end
end
