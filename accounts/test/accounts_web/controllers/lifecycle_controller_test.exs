defmodule AccountsWeb.LifecycleControllerTest do
  # Smoke tests: each transition route answers with the status openapi.yaml documents. The FSM
  # itself is covered by the aggregate tests. Commands reach the real event store, which has no
  # sandbox, hence async: false and a fresh account id in each test.
  use AccountsWeb.ConnCase, async: false

  import AccountsWeb.ApiSpec

  alias Accounts.App
  alias Accounts.Commands.ActivateCustomerAccount
  alias Accounts.Commands.BlockCustomerAccount
  alias Accounts.Commands.FreezeCustomerAccount
  alias Accounts.Commands.OpenCustomerAccount

  @moduletag :integration

  test "POST /api/accounts/:account_id/activate", %{conn: conn} do
    id = account_in([])

    assert_response_schema(post(conn, ~p"/api/accounts/#{id}/activate"), 204)
  end

  test "POST /api/accounts/:account_id/block", %{conn: conn} do
    id = account_in([:activate])

    conn = post(conn, ~p"/api/accounts/#{id}/block", %{reason: "suspected fraud"})

    assert_response_schema(conn, 204)
  end

  test "POST /api/accounts/:account_id/unblock", %{conn: conn} do
    id = account_in([:activate, :block])

    assert_response_schema(post(conn, ~p"/api/accounts/#{id}/unblock"), 204)
  end

  test "POST /api/accounts/:account_id/freeze", %{conn: conn} do
    id = account_in([:activate])

    conn = post(conn, ~p"/api/accounts/#{id}/freeze", %{reason: "court order"})

    assert_response_schema(conn, 204)
  end

  test "POST /api/accounts/:account_id/unfreeze", %{conn: conn} do
    id = account_in([:activate, :freeze])

    assert_response_schema(post(conn, ~p"/api/accounts/#{id}/unfreeze"), 204)
  end

  test "POST /api/accounts/:account_id/close", %{conn: conn} do
    id = account_in([:activate])

    assert_response_schema(post(conn, ~p"/api/accounts/#{id}/close"), 204)
  end

  describe "errors" do
    test "a transition the FSM does not allow is 409", %{conn: conn} do
      id = account_in([])

      conn = post(conn, ~p"/api/accounts/#{id}/unblock")

      assert %{"errors" => %{"code" => "invalid_transition"}} = assert_response_schema(conn, 409)
    end

    test "an account that was never opened is 404", %{conn: conn} do
      conn = post(conn, ~p"/api/accounts/#{Ecto.UUID.generate()}/activate")

      assert %{"errors" => %{"code" => "account_not_found"}} = assert_response_schema(conn, 404)
    end

    test "blocking without a reason is 422", %{conn: conn} do
      id = account_in([:activate])

      conn = post(conn, ~p"/api/accounts/#{id}/block")

      assert %{"errors" => %{"code" => "reason_required"}} = assert_response_schema(conn, 422)
    end
  end

  # Opens an account and walks it through the given transitions, straight on the aggregate.
  defp account_in(transitions) do
    id = Ecto.UUID.generate()
    :ok = App.dispatch(%OpenCustomerAccount{account_id: id, customer_id: Ecto.UUID.generate()})

    for transition <- transitions do
      :ok =
        App.dispatch(
          case transition do
            :activate -> %ActivateCustomerAccount{account_id: id}
            :block -> %BlockCustomerAccount{account_id: id, reason: "suspected fraud"}
            :freeze -> %FreezeCustomerAccount{account_id: id, reason: "court order"}
          end
        )
    end

    id
  end
end
