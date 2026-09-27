# The stories drive the running services: fail fast, with the fix, when they are not up.
preflight = fn name, url, path, hint ->
  case Req.get(url <> path, retry: false) do
    {:ok, %{status: 200}} ->
      :ok

    other ->
      raise """
      #{name} is not ready at #{url}#{path} (got #{inspect(other, limit: 3)}).

      #{hint}
      """
  end
end

start_hint = """
Start the stack first (see apps/e2e/README.md):

    docker compose up -d --wait     # from the repo root: infrastructure and both services

Or, with the services on the host, only the infrastructure in Docker:

    docker compose up -d postgres rabbitmq swagger-ui
    (cd apps/ledger && iex -S mix phx.server)
    (cd apps/accounts && iex -S mix phx.server)
"""

preflight.(
  "Accounts",
  Application.fetch_env!(:e2e, :accounts_url),
  "/api/accounts?customer_id=e2e",
  start_hint
)

preflight.("Ledger", Application.fetch_env!(:e2e, :ledger_url), "/api/trial-balance", start_hint)

preflight.(
  "The PIX settlement account",
  Application.fetch_env!(:e2e, :ledger_url),
  "/api/ledger-accounts/pix-settlement",
  "Deposits debit it. Open it with the Ledger's seeds: (cd apps/ledger && mix run priv/repo/seeds.exs)"
)

ExUnit.start()
