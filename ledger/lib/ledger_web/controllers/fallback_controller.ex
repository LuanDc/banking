defmodule LedgerWeb.FallbackController do
  @moduledoc """
  Turns a controller's `{:error, reason}` into the error response openapi.yaml documents for it
  (README, D12). The reason becomes the `code`.
  """

  use LedgerWeb, :controller

  @statuses %{
    not_found: :not_found,
    invalid_query: :unprocessable_entity
  }

  @details %{
    not_found: "Not Found",
    invalid_query: "A query parameter is invalid."
  }

  def call(conn, {:error, reason}) when is_map_key(@statuses, reason) do
    conn
    |> put_status(Map.fetch!(@statuses, reason))
    |> put_view(json: LedgerWeb.ErrorJSON)
    |> render(:error, code: reason, detail: Map.fetch!(@details, reason))
  end
end
