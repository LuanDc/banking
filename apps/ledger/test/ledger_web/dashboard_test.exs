defmodule LedgerWeb.DashboardTest do
  # Changes the application env, so it runs alone.
  use LedgerWeb.ConnCase, async: false

  @credentials Application.compile_env!(:ledger, :dashboard)

  test "asks for the credentials", %{conn: conn} do
    conn = get(conn, "/dashboard")

    assert conn.status == 401
  end

  test "opens with the credentials", %{conn: conn} do
    conn =
      conn
      |> put_req_header("authorization", basic_auth(@credentials))
      |> get("/dashboard")

    assert redirected_to(conn) == "/dashboard/home"
  end

  test "is not served when no credentials are configured", %{conn: conn} do
    Application.put_env(:ledger, :dashboard, nil)
    on_exit(fn -> Application.put_env(:ledger, :dashboard, @credentials) end)

    conn =
      conn
      |> put_req_header("authorization", basic_auth(@credentials))
      |> get("/dashboard")

    assert conn.status == 404
  end

  defp basic_auth(credentials) do
    Plug.BasicAuth.encode_basic_auth(credentials[:username], credentials[:password])
  end
end
