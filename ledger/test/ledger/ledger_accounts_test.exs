defmodule Ledger.LedgerAccountsTest do
  # The context's queries over the read models.
  use Ledger.DataCase, async: true

  alias Ledger.LedgerAccounts

  describe "get_balance/1" do
    test "returns the account's totals and balance" do
      account = insert(:ledger_account)

      insert(:account_balance,
        account_id: account.account_id,
        debit_total: 400,
        credit_total: 1_000
      )

      assert {:ok, %{debit_total: 400, credit_total: 1_000, balance: 600}} =
               LedgerAccounts.get_balance(account.account_id)
    end

    test "is zero for an open account with nothing booked yet" do
      account = insert(:ledger_account)

      assert {:ok, %{debit_total: 0, credit_total: 0, balance: 0, updated_at: nil}} =
               LedgerAccounts.get_balance(account.account_id)
    end

    test "is not found for an unknown account" do
      assert {:error, :not_found} = LedgerAccounts.get_balance("unknown")
    end
  end

  describe "list_entries/1" do
    test "pages the account's statement, newest first" do
      account = insert(:ledger_account)
      [first, second, third] = insert_list(3, :statement_entry, account_id: account.account_id)
      insert(:statement_entry, account_id: "other")
      params = %{"account_id" => account.account_id, "limit" => "2"}

      assert {:ok, page} = LedgerAccounts.list_entries(params)
      assert Enum.map(page.data, & &1.id) == [third.id, second.id]

      assert {:ok, last} = LedgerAccounts.list_entries(Map.put(params, "after", page.next_cursor))
      assert Enum.map(last.data, & &1.id) == [first.id]
      assert last.next_cursor == nil
    end

    test "keeps entries booked from `from` and before `to`" do
      account = insert(:ledger_account)
      booked_at = fn day -> DateTime.new!(Date.new!(2026, 9, day), ~T[12:00:00.000000]) end

      for day <- [24, 25, 26] do
        insert(:statement_entry, account_id: account.account_id, booked_at: booked_at.(day))
      end

      params = %{
        "account_id" => account.account_id,
        "from" => "2026-09-25T00:00:00Z",
        "to" => "2026-09-26T00:00:00Z"
      }

      assert {:ok, %{data: [entry]}} = LedgerAccounts.list_entries(params)
      assert entry.booked_at == booked_at.(25)
    end

    test "rejects a date, limit or cursor it does not know" do
      account = insert(:ledger_account)

      for invalid <- [%{"from" => "yesterday"}, %{"limit" => "101"}, %{"after" => "-1"}] do
        params = Map.put(invalid, "account_id", account.account_id)

        assert {:error, :invalid_query} = LedgerAccounts.list_entries(params)
      end
    end
  end

  describe "get_trial_balance/0" do
    test "totals every account and tells whether debits equal credits" do
      insert(:account_balance, debit_total: 1_000, credit_total: 0)
      insert(:account_balance, debit_total: 0, credit_total: 1_000)

      assert %{debit_total: 1_000, credit_total: 1_000, balanced: true} =
               LedgerAccounts.get_trial_balance()
    end
  end
end
