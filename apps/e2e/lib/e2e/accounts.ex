defmodule E2E.Accounts do
  @moduledoc """
  HTTP client for the Accounts API (`apps/accounts/priv/openapi.yaml`).

  Every function returns the raw `Req.Response`, so a story asserts on the status and the
  body exactly as a client of the API would see them.
  """

  @type response :: Req.Response.t()

  @spec open_account(String.t()) :: response
  def open_account(customer_id), do: post("/api/accounts", json: %{customer_id: customer_id})

  @spec get_account(String.t()) :: response
  def get_account(account_id), do: get("/api/accounts/#{account_id}")

  @spec status_history(String.t()) :: response
  def status_history(account_id), do: get("/api/accounts/#{account_id}/status-history")

  @doc "A lifecycle transition: `activate`, `block`, `unblock`, `freeze`, `unfreeze` or `close`."
  @spec transition(String.t(), String.t(), String.t() | nil) :: response
  def transition(account_id, action, reason \\ nil) do
    body = if reason, do: [json: %{reason: reason}], else: []
    post("/api/accounts/#{account_id}/#{action}", body)
  end

  @spec deposit(String.t(), integer(), String.t()) :: response
  def deposit(account_id, amount, idempotency_key) do
    post("/api/accounts/#{account_id}/deposits",
      json: %{amount: amount},
      headers: [{"idempotency-key", idempotency_key}]
    )
  end

  @spec transfer(String.t(), String.t(), integer(), String.t()) :: response
  def transfer(from_account_id, to_account_id, amount, idempotency_key) do
    post("/api/transfers",
      json: %{from_account_id: from_account_id, to_account_id: to_account_id, amount: amount},
      headers: [{"idempotency-key", idempotency_key}]
    )
  end

  @spec get_transfer(String.t()) :: response
  def get_transfer(correlation_id), do: get("/api/transfers/#{correlation_id}")

  @spec reservations(String.t()) :: response
  def reservations(account_id), do: get("/api/accounts/#{account_id}/reservations")

  @spec credits(String.t()) :: response
  def credits(account_id), do: get("/api/accounts/#{account_id}/credits")

  defp get(path), do: Req.get!(client(), url: path)

  defp post(path, opts), do: Req.post!(client(), [url: path] ++ opts)

  defp client, do: Req.new(base_url: Application.fetch_env!(:e2e, :accounts_url), retry: false)
end
