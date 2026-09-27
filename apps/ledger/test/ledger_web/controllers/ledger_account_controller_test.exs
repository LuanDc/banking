defmodule LedgerWeb.LedgerAccountControllerTest do
  # Smoke tests: each route answers with the status and shape openapi.yaml documents. The queries
  # behind them are covered by the context tests.
  use LedgerWeb.ConnCase, async: true

  import LedgerWeb.ApiSpec

  test "GET /api/ledger-accounts/:account_id", %{conn: conn} do
    account = insert(:ledger_account)

    conn = get(conn, ~p"/api/ledger-accounts/#{account.account_id}")

    assert %{"status" => "open"} = assert_response_schema(conn, 200)
  end

  test "GET /api/ledger-accounts/:account_id returns 404 for an unknown account", %{conn: conn} do
    conn = get(conn, ~p"/api/ledger-accounts/#{Ecto.UUID.generate()}")

    assert %{"errors" => %{"code" => "not_found"}} = assert_response_schema(conn, 404)
  end

  test "GET /api/ledger-accounts/:account_id/balance", %{conn: conn} do
    account = insert(:ledger_account)
    insert(:account_balance, account_id: account.account_id, credit_total: 1_000)

    conn = get(conn, ~p"/api/ledger-accounts/#{account.account_id}/balance")

    assert %{"balance" => 1_000} = assert_response_schema(conn, 200)
  end

  test "GET /api/ledger-accounts/:account_id/entries", %{conn: conn} do
    account = insert(:ledger_account)
    insert(:statement_entry, account_id: account.account_id)

    conn = get(conn, ~p"/api/ledger-accounts/#{account.account_id}/entries")

    assert %{"data" => [%{"type" => "credit"}], "next_cursor" => nil} =
             assert_response_schema(conn, 200)
  end

  test "GET /api/ledger-accounts/:account_id/entries returns 422 for an invalid query",
       %{conn: conn} do
    account = insert(:ledger_account)

    conn = get(conn, ~p"/api/ledger-accounts/#{account.account_id}/entries?from=yesterday")

    assert %{"errors" => %{"code" => "invalid_query"}} = assert_response_schema(conn, 422)
  end

  test "GET /api/batches/:batch_id", %{conn: conn} do
    # A fresh id: async tests inserting the same (batch_id, position) deadlock on its index.
    batch_id = Ecto.UUID.generate()
    insert(:statement_entry, batch_id: batch_id, position: 0, type: :debit)
    insert(:statement_entry, batch_id: batch_id, position: 1, type: :credit)

    conn = get(conn, ~p"/api/batches/#{batch_id}")

    assert %{"entries" => [_debit, _credit]} = assert_response_schema(conn, 200)
  end

  test "GET /api/batches?transfer_id=", %{conn: conn} do
    transfer_id = Ecto.UUID.generate()
    batch_id = Ecto.UUID.generate()

    insert(:statement_entry,
      batch_id: batch_id,
      transfer_id: transfer_id,
      position: 0,
      type: :debit
    )

    insert(:statement_entry,
      batch_id: batch_id,
      transfer_id: transfer_id,
      position: 1,
      type: :credit
    )

    conn = get(conn, ~p"/api/batches?transfer_id=#{transfer_id}")

    assert %{"data" => [%{"batch_id" => ^batch_id, "transfer_id" => ^transfer_id}]} =
             assert_response_schema(conn, 200)
  end

  test "GET /api/batches without a transfer_id", %{conn: conn} do
    conn = get(conn, ~p"/api/batches")

    assert %{"errors" => %{"code" => "invalid_query"}} = assert_response_schema(conn, 422)
  end

  test "GET /api/trial-balance", %{conn: conn} do
    insert(:account_balance, debit_total: 1_000, credit_total: 0)
    insert(:account_balance, debit_total: 0, credit_total: 1_000)

    conn = get(conn, ~p"/api/trial-balance")

    assert %{"balanced" => true} = assert_response_schema(conn, 200)
  end
end
