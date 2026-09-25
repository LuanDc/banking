defmodule AccountsWeb.AccountControllerTest do
  # Smoke tests: each route answers with the status and shape openapi.yaml documents. The rules
  # behind them are covered by the aggregate and projection tests.
  use AccountsWeb.ConnCase, async: true

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
end
