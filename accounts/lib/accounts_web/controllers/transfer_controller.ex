defmodule AccountsWeb.TransferController do
  use AccountsWeb, :controller

  alias Accounts.CustomerAccounts

  action_fallback AccountsWeb.FallbackController

  def create(conn, params) do
    with {:ok, transfer} <- CustomerAccounts.transfer_money(params, idempotency_key(conn)) do
      conn
      |> put_status(:accepted)
      |> put_resp_header("location", ~p"/api/transfers/#{transfer.correlation_id}")
      |> render(:show, transfer: transfer)
    end
  end

  def show(conn, %{"correlation_id" => correlation_id}) do
    with {:ok, transfer} <- CustomerAccounts.get_transfer(correlation_id) do
      render(conn, :show, transfer: transfer)
    end
  end

  def deposit(conn, params) do
    with {:ok, deposit} <- CustomerAccounts.deposit(params, idempotency_key(conn)) do
      conn
      |> put_status(:accepted)
      |> render(:deposit, deposit: deposit)
    end
  end

  # README, D4: the client's key is the correlation id.
  defp idempotency_key(conn) do
    conn
    |> get_req_header("idempotency-key")
    |> List.first()
  end
end
