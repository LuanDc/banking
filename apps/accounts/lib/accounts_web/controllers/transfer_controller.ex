defmodule AccountsWeb.TransferController do
  use AccountsWeb, :controller

  alias Accounts.CustomerAccounts

  action_fallback AccountsWeb.FallbackController

  def create(conn, params) do
    with {:ok, transfer} <- CustomerAccounts.transfer_money(params, idempotency_key(conn)) do
      conn
      |> put_status(:accepted)
      |> put_resp_header("location", ~p"/api/transfers/#{transfer.transfer_id}")
      |> render(:show, transfer: transfer)
    end
  end

  def show(conn, %{"transfer_id" => transfer_id}) do
    with {:ok, transfer} <- CustomerAccounts.get_transfer(transfer_id) do
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

  # README, D17: the client's key answers its retries; the transfer has an id of its own.
  defp idempotency_key(conn) do
    conn
    |> get_req_header("idempotency-key")
    |> List.first()
  end
end
