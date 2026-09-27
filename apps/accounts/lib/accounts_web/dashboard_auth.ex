defmodule AccountsWeb.DashboardAuth do
  @moduledoc """
  Guards /dashboard with HTTP basic auth, from `config :accounts, :dashboard, username: ...,
  password: ...` (in prod, `DASHBOARD_USER` and `DASHBOARD_PASSWORD`). With no credentials
  configured, the dashboard is not served at all.
  """

  @behaviour Plug

  import Plug.Conn

  @impl Plug
  def init(opts), do: opts

  @impl Plug
  def call(conn, _opts) do
    case Application.get_env(:accounts, :dashboard) do
      [username: username, password: password] ->
        Plug.BasicAuth.basic_auth(conn, username: username, password: password)

      _not_configured ->
        conn
        |> send_resp(:not_found, "Not Found")
        |> halt()
    end
  end
end
