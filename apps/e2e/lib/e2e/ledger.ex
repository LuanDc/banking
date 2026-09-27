defmodule E2E.Ledger do
  @moduledoc """
  HTTP client for the Ledger's read-only API (`apps/ledger/priv/openapi.yaml`).
  """

  @type response :: Req.Response.t()

  @spec ledger_account(String.t()) :: response
  def ledger_account(account_id), do: get("/api/ledger-accounts/#{account_id}")

  @spec balance(String.t()) :: response
  def balance(account_id), do: get("/api/ledger-accounts/#{account_id}/balance")

  @spec entries(String.t()) :: response
  def entries(account_id), do: get("/api/ledger-accounts/#{account_id}/entries")

  @spec batch(String.t()) :: response
  def batch(batch_id), do: get("/api/batches/#{batch_id}")

  @spec trial_balance() :: response
  def trial_balance, do: get("/api/trial-balance")

  defp get(path), do: Req.get!(client(), url: path)

  defp client, do: Req.new(base_url: Application.fetch_env!(:e2e, :ledger_url), retry: false)
end
