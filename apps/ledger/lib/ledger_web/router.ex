defmodule LedgerWeb.Router do
  use LedgerWeb, :router

  import Phoenix.LiveDashboard.Router

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :dashboard do
    plug LedgerWeb.DashboardAuth
    plug :fetch_session
    plug :protect_from_forgery
    plug :put_dashboard_headers
  end

  # The metrics to watch during a load test (LedgerWeb.Telemetry) and the Postgres stats of the
  # read-model database.
  scope "/" do
    pipe_through :dashboard

    live_dashboard "/dashboard",
      metrics: LedgerWeb.Telemetry,
      ecto_repos: [Ledger.Repo],
      csp_nonce_assign_key: %{script: :script_nonce},
      ecto_psql_extras_options: [long_running_queries: [threshold: "200 milliseconds"]]
  end

  scope "/api", LedgerWeb do
    pipe_through :api

    get "/ledger-accounts/:account_id", LedgerAccountController, :show
    get "/ledger-accounts/:account_id/balance", LedgerAccountController, :balance
    get "/ledger-accounts/:account_id/entries", LedgerAccountController, :entries
    get "/batches/:batch_id", BatchController, :show
    get "/trial-balance", LedgerAccountController, :trial_balance
  end

  # Scripts run only with this request's nonce. Inline styles stay allowed: LiveView sets style
  # attributes as it patches the charts.
  defp put_dashboard_headers(conn, _opts) do
    nonce = 18 |> :crypto.strong_rand_bytes() |> Base.url_encode64(padding: false)

    conn
    |> assign(:script_nonce, nonce)
    |> put_secure_browser_headers(%{
      "content-security-policy" =>
        "default-src 'self'; script-src 'self' 'nonce-#{nonce}'; " <>
          "style-src 'self' 'unsafe-inline'; img-src 'self' data:; font-src 'self' data:"
    })
  end
end
