defmodule Accounts.CustomerAccountsTest do
  # The context's queries over the read models. Its commands are covered by the aggregate tests
  # and the controller smoke tests.
  use Accounts.DataCase, async: true

  alias Accounts.CustomerAccounts

  describe "list_customer_accounts/1" do
    test "lists only the customer's accounts" do
      mine = insert(:customer_account, customer_id: "cus-1")
      insert(:customer_account, customer_id: "cus-2")

      assert {:ok, [account]} =
               CustomerAccounts.list_customer_accounts(%{"customer_id" => "cus-1"})

      assert account.account_id == mine.account_id
    end

    test "needs a customer_id" do
      assert {:error, :customer_id_required} = CustomerAccounts.list_customer_accounts(%{})
    end
  end

  describe "list_status_changes/1" do
    test "lists the account's transitions, oldest first" do
      account = insert(:customer_account)
      opened = insert(:status_change, account_id: account.account_id, status: :pending_kyc)
      activated = insert(:status_change, account_id: account.account_id, status: :active)
      insert(:status_change)

      assert {:ok, changes} = CustomerAccounts.list_status_changes(account.account_id)
      assert Enum.map(changes, & &1.id) == [opened.id, activated.id]
    end

    test "is not found for an unknown account" do
      assert {:error, :not_found} = CustomerAccounts.list_status_changes("unknown")
    end
  end

  describe "list_reservations/1" do
    test "pages the account's reservations, newest first" do
      account = insert(:customer_account)
      [first, second, third] = insert_list(3, :reservation, account_id: account.account_id)
      insert(:reservation, account_id: "other")
      params = %{"account_id" => account.account_id, "limit" => "2"}

      assert {:ok, page} = CustomerAccounts.list_reservations(params)
      assert Enum.map(page.data, & &1.id) == [third.id, second.id]

      assert {:ok, last} =
               CustomerAccounts.list_reservations(Map.put(params, "after", page.next_cursor))

      assert Enum.map(last.data, & &1.id) == [first.id]
      assert last.next_cursor == nil
    end

    test "filters by status" do
      account = insert(:customer_account)
      open = insert(:reservation, account_id: account.account_id, status: :open)
      insert(:reservation, account_id: account.account_id, status: :confirmed)

      params = %{"account_id" => account.account_id, "status" => "open"}

      assert {:ok, %{data: [reservation]}} = CustomerAccounts.list_reservations(params)
      assert reservation.id == open.id
    end

    test "rejects a status, limit or cursor it does not know" do
      account = insert(:customer_account)

      for invalid <- [%{"status" => "weird"}, %{"limit" => "0"}, %{"after" => "x"}] do
        params = Map.put(invalid, "account_id", account.account_id)

        assert {:error, :invalid_query} = CustomerAccounts.list_reservations(params)
      end
    end

    test "is not found for an unknown account" do
      assert {:error, :not_found} =
               CustomerAccounts.list_reservations(%{"account_id" => "unknown"})
    end
  end

  describe "list_credits/1" do
    test "pages and filters the account's credits like the reservations" do
      account = insert(:customer_account)
      insert(:credit, account_id: account.account_id, status: :posted)
      authorized = insert(:credit, account_id: account.account_id, status: :authorized)
      insert(:credit, account_id: "other", status: :authorized)

      params = %{"account_id" => account.account_id, "status" => "authorized"}

      assert {:ok, %{data: [credit], next_cursor: nil}} = CustomerAccounts.list_credits(params)
      assert credit.id == authorized.id
    end
  end

  describe "get_transfer/1" do
    test "a transfer is pending while its reservation is open" do
      reservation = insert(:reservation, to_account_id: "acc-2", status: :open)

      assert {:ok,
              %{
                correlation_id: correlation_id,
                from_account_id: from,
                to_account_id: "acc-2",
                amount: 400,
                status: :pending,
                reason: nil
              }} = CustomerAccounts.get_transfer(reservation.correlation_id)

      assert {correlation_id, from} == {reservation.correlation_id, reservation.account_id}
    end

    test "completes once the reservation is confirmed" do
      reservation = insert(:reservation, to_account_id: "acc-2", status: :confirmed)

      assert {:ok, %{status: :completed, reason: nil}} =
               CustomerAccounts.get_transfer(reservation.correlation_id)
    end

    test "fails with the reservation's rejection" do
      reservation =
        insert(:reservation, status: :rejected, reason: "insufficient_balance")

      assert {:ok, %{status: :failed, reason: "insufficient_balance"}} =
               CustomerAccounts.get_transfer(reservation.correlation_id)
    end

    test "fails with the credit's rejection once the reservation is released" do
      reservation = insert(:reservation, to_account_id: "acc-2", status: :released)

      insert(:credit,
        account_id: "acc-2",
        correlation_id: reservation.correlation_id,
        status: :rejected,
        reason: "credit_not_allowed"
      )

      assert {:ok, %{status: :failed, reason: "credit_not_allowed"}} =
               CustomerAccounts.get_transfer(reservation.correlation_id)
    end

    test "fails as batch_rejected when the Ledger refused the batch" do
      reservation = insert(:reservation, to_account_id: "acc-2", status: :released)

      insert(:credit,
        account_id: "acc-2",
        correlation_id: reservation.correlation_id,
        status: :cancelled
      )

      assert {:ok, %{status: :failed, reason: "batch_rejected"}} =
               CustomerAccounts.get_transfer(reservation.correlation_id)
    end

    test "is not found without a reservation, e.g. for a deposit" do
      assert {:error, :not_found} = CustomerAccounts.get_transfer("unknown")
    end
  end
end
