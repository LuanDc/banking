defmodule AccountsWeb.TransferControllerTest do
  # Smoke tests: each route answers with the status and shape openapi.yaml documents. The saga's
  # rules are covered by the aggregate, policy and inbox tests. Commands reach the real event
  # store, which has no sandbox, hence async: false and fresh ids in each test.
  use AccountsWeb.ConnCase, async: false

  import AccountsWeb.ApiSpec

  alias Accounts.App
  alias Accounts.Commands.ActivateCustomerAccount
  alias Accounts.Commands.FreezeCustomerAccount
  alias Accounts.Commands.OpenCustomerAccount
  alias Accounts.Commands.PostCredit

  @moduletag :integration

  describe "POST /api/transfers" do
    test "reserves the amount and starts the saga", %{conn: conn} do
      from = active_account(balance: 1_000)
      key = Ecto.UUID.generate()

      conn =
        transfer(conn, key, %{from_account_id: from, to_account_id: active_account(), amount: 400})

      assert %{"correlation_id" => ^key, "status" => "pending"} =
               assert_response_schema(conn, 202)

      assert get_resp_header(conn, "location") == ["/api/transfers/#{key}"]
    end

    test "a repeated key starts nothing new", %{conn: conn} do
      from = active_account(balance: 1_000)
      key = Ecto.UUID.generate()
      body = %{from_account_id: from, to_account_id: active_account(), amount: 400}

      transfer(build_conn(), key, body)

      assert %{"correlation_id" => ^key} = assert_response_schema(transfer(conn, key, body), 202)
    end

    test "returns 422 with the reservation's rejection", %{conn: conn} do
      body = %{from_account_id: active_account(), to_account_id: active_account(), amount: 400}

      conn = transfer(conn, Ecto.UUID.generate(), body)

      assert %{"errors" => %{"code" => "insufficient_balance"}} =
               assert_response_schema(conn, 422)
    end

    test "returns 404 for a source account that was never opened", %{conn: conn} do
      body = %{from_account_id: Ecto.UUID.generate(), to_account_id: active_account(), amount: 1}

      conn = transfer(conn, Ecto.UUID.generate(), body)

      assert %{"errors" => %{"code" => "account_not_found"}} = assert_response_schema(conn, 404)
    end

    test "returns 422 without an Idempotency-Key", %{conn: conn} do
      conn =
        post(conn, ~p"/api/transfers", %{from_account_id: "a", to_account_id: "b", amount: 1})

      assert %{"errors" => %{"code" => "validation_failed", "fields" => %{"correlation_id" => _}}} =
               assert_response_schema(conn, 422)
    end
  end

  describe "GET /api/transfers/:correlation_id" do
    test "returns the transfer as it stands", %{conn: conn} do
      reservation = insert(:reservation, to_account_id: Ecto.UUID.generate())

      conn = get(conn, ~p"/api/transfers/#{reservation.correlation_id}")

      assert %{"status" => "pending"} = assert_response_schema(conn, 200)
    end

    test "returns 404 for an unknown transfer", %{conn: conn} do
      conn = get(conn, ~p"/api/transfers/#{Ecto.UUID.generate()}")

      assert %{"errors" => %{"code" => "not_found"}} = assert_response_schema(conn, 404)
    end
  end

  describe "POST /api/accounts/:account_id/deposits" do
    test "authorizes the credit and sends it to the Ledger", %{conn: conn} do
      account = active_account()

      conn = deposit(conn, account, %{amount: 1_000})

      assert %{"account_id" => ^account, "amount" => 1_000} = assert_response_schema(conn, 202)
    end

    test "returns 422 when the account may not receive money", %{conn: conn} do
      account = active_account()
      :ok = App.dispatch(%FreezeCustomerAccount{account_id: account, reason: "court order"})

      conn = deposit(conn, account, %{amount: 1_000})

      assert %{"errors" => %{"code" => "credit_not_allowed"}} = assert_response_schema(conn, 422)
    end
  end

  defp transfer(conn, key, body) do
    conn
    |> put_req_header("idempotency-key", key)
    |> post(~p"/api/transfers", body)
  end

  defp deposit(conn, account_id, body) do
    conn
    |> put_req_header("idempotency-key", Ecto.UUID.generate())
    |> post(~p"/api/accounts/#{account_id}/deposits", body)
  end

  # An active account, holding `balance` as if the Ledger had booked a credit into it.
  defp active_account(opts \\ []) do
    id = Ecto.UUID.generate()
    :ok = App.dispatch(%OpenCustomerAccount{account_id: id, customer_id: Ecto.UUID.generate()})
    :ok = App.dispatch(%ActivateCustomerAccount{account_id: id})

    case Keyword.get(opts, :balance, 0) do
      0 ->
        id

      balance ->
        credit = %PostCredit{
          account_id: id,
          amount: balance,
          correlation_id: Ecto.UUID.generate()
        }

        :ok = App.dispatch(credit)
        id
    end
  end
end
