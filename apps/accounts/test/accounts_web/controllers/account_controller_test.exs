defmodule AccountsWeb.AccountControllerTest do
  # Smoke tests: each route answers with the status and shape openapi.yaml documents. The rules
  # behind them are covered by the aggregate and projection tests. Commands reach the real event
  # store, which has no sandbox, hence async: false and a fresh account id in each test.
  use AccountsWeb.ConnCase, async: false

  import AccountsWeb.ApiSpec

  describe "GET /api/accounts/:account_id" do
    test "returns the account from the read model", %{conn: conn} do
      account = insert(:customer_account)

      conn = get(conn, ~p"/api/accounts/#{account.account_id}")

      assert %{"account_id" => id} = assert_response_schema(conn, 200)
      assert id == account.account_id
    end

    test "returns 404 for an unknown account", %{conn: conn} do
      conn = get(conn, ~p"/api/accounts/#{Ecto.UUID.generate()}")

      assert %{"errors" => %{"code" => "not_found"}} = assert_response_schema(conn, 404)
    end
  end

  describe "POST /api/accounts" do
    @describetag :integration

    test "opens an account pending KYC", %{conn: conn} do
      conn = post(conn, ~p"/api/accounts", %{customer_id: Ecto.UUID.generate()})

      assert %{"account_id" => id, "status" => "pending_kyc"} = assert_response_schema(conn, 201)
      assert get_resp_header(conn, "location") == ["/api/accounts/#{id}"]
    end

    test "returns 422 without a customer_id", %{conn: conn} do
      conn = post(conn, ~p"/api/accounts", %{})

      assert %{"errors" => %{"code" => "validation_failed", "fields" => %{"customer_id" => _}}} =
               assert_response_schema(conn, 422)
    end
  end

  describe "GET /api/accounts" do
    test "lists the customer's accounts", %{conn: conn} do
      account = insert(:customer_account)

      conn = get(conn, ~p"/api/accounts?customer_id=#{account.customer_id}")

      assert %{"data" => [%{"account_id" => id}]} = assert_response_schema(conn, 200)
      assert id == account.account_id
    end

    test "returns 422 without a customer_id", %{conn: conn} do
      conn = get(conn, ~p"/api/accounts")

      assert %{"errors" => %{"code" => "invalid_query"}} =
               assert_response_schema(conn, 422)
    end
  end

  describe "GET /api/accounts/:account_id/status-history" do
    test "lists the account's transitions", %{conn: conn} do
      change = insert(:status_change, reason: nil)

      conn = get(conn, ~p"/api/accounts/#{change.account_id}/status-history")

      assert %{"data" => [%{"event" => "CustomerAccountOpened"}]} =
               assert_response_schema(conn, 200)
    end
  end

  describe "GET /api/accounts/:account_id/reservations" do
    test "pages the account's reservations", %{conn: conn} do
      reservation = insert(:reservation, account_id: insert(:customer_account).account_id)

      conn = get(conn, ~p"/api/accounts/#{reservation.account_id}/reservations?status=open")

      assert %{"data" => [%{"status" => "open"}], "next_cursor" => nil} =
               assert_response_schema(conn, 200)
    end

    test "returns 422 for an invalid query", %{conn: conn} do
      account = insert(:customer_account)

      conn = get(conn, ~p"/api/accounts/#{account.account_id}/reservations?status=weird")

      assert %{"errors" => %{"code" => "invalid_query"}} = assert_response_schema(conn, 422)
    end
  end

  describe "GET /api/accounts/:account_id/credits" do
    test "pages the account's credits", %{conn: conn} do
      credit = insert(:credit, account_id: insert(:customer_account).account_id)

      conn = get(conn, ~p"/api/accounts/#{credit.account_id}/credits")

      assert %{"data" => [%{"status" => "authorized"}], "next_cursor" => nil} =
               assert_response_schema(conn, 200)
    end
  end
end
