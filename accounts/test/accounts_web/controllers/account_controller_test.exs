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

      assert %{"errors" => %{"code" => "customer_id_required"}} =
               assert_response_schema(conn, 422)
    end
  end
end
