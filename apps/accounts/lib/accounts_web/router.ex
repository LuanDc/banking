defmodule AccountsWeb.Router do
  use AccountsWeb, :router

  import Phoenix.LiveDashboard.Router

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :dashboard do
    plug AccountsWeb.DashboardAuth
    plug :fetch_session
    plug :protect_from_forgery
    plug :put_dashboard_headers
  end

  # The metrics to watch during a load test (AccountsWeb.Telemetry) and the Postgres stats of the
  # read-model database.
  scope "/" do
    pipe_through :dashboard

    live_dashboard "/dashboard",
      metrics: AccountsWeb.Telemetry,
      ecto_repos: [Accounts.Repo],
      csp_nonce_assign_key: %{script: :script_nonce},
      ecto_psql_extras_options: [long_running_queries: [threshold: "200 milliseconds"]]
  end

  scope "/api", AccountsWeb do
    pipe_through :api

    get "/accounts", AccountController, :index
    post "/accounts", AccountController, :create
    get "/accounts/:account_id", AccountController, :show
    get "/accounts/:account_id/status-history", AccountController, :status_history
    get "/accounts/:account_id/reservations", ReservationController, :index
    get "/accounts/:account_id/credits", CreditController, :index
    post "/accounts/:account_id/deposits", TransferController, :deposit

    post "/transfers", TransferController, :create
    get "/transfers/:correlation_id", TransferController, :show

    post "/accounts/:account_id/activate", LifecycleController, :activate
    post "/accounts/:account_id/block", LifecycleController, :block
    post "/accounts/:account_id/unblock", LifecycleController, :unblock
    post "/accounts/:account_id/freeze", LifecycleController, :freeze
    post "/accounts/:account_id/unfreeze", LifecycleController, :unfreeze
    post "/accounts/:account_id/close", LifecycleController, :close
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
