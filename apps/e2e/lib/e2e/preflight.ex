defmodule E2E.Preflight do
  @moduledoc """
  Fails fast, with the fix, when the services a story or a load test drives are not up.
  """

  @start_hint """
  Start the stack first, from the repo root (see apps/e2e/README.md):

      docker compose up -d --build --wait

  Or point ACCOUNTS_URL, LEDGER_URL and RABBITMQ_URL at where it runs.

  Or, with the services on the host, only the infrastructure in Docker:

      docker compose up -d postgres rabbitmq swagger-ui
      (cd apps/ledger && iex -S mix phx.server)
      (cd apps/accounts && iex -S mix phx.server)
  """

  @doc "Raises unless both services answer and the Ledger has the PIX settlement account."
  @spec check!() :: :ok
  def check! do
    accounts_url = Application.fetch_env!(:e2e, :accounts_url)
    ledger_url = Application.fetch_env!(:e2e, :ledger_url)

    ready!("Accounts", accounts_url <> "/api/accounts?customer_id=e2e", @start_hint)
    ready!("Ledger", ledger_url <> "/api/trial-balance", @start_hint)

    ready!(
      "The PIX settlement account",
      ledger_url <> "/api/ledger-accounts/pix-settlement",
      "Deposits debit it. Open it with the Ledger's seeds: " <>
        "(cd apps/ledger && mix run priv/repo/seeds.exs)"
    )
  end

  defp ready!(name, url, hint) do
    case Req.get(url, retry: false) do
      {:ok, %{status: 200}} ->
        :ok

      other ->
        raise """
        #{name} is not ready at #{url} (got #{inspect(other, limit: 3)}).

        #{hint}
        """
    end
  end
end
