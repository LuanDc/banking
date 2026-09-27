defmodule AccountsWeb.FallbackController do
  @moduledoc """
  Turns a controller's `{:error, reason}` into the error response openapi.yaml documents for it
  (README, D12). The reason becomes the `code`.
  """

  use AccountsWeb, :controller

  @statuses %{
    not_found: :not_found,
    account_not_found: :not_found,
    invalid_transition: :conflict,
    balance_not_zero: :conflict,
    open_reservations: :conflict,
    pending_credits: :conflict,
    invalid_query: :unprocessable_entity,
    account_not_active: :unprocessable_entity,
    insufficient_balance: :unprocessable_entity,
    credit_not_allowed: :unprocessable_entity,
    idempotency_key_reused: :unprocessable_entity
  }

  @details %{
    not_found: "Not Found",
    account_not_found: "The account does not exist.",
    invalid_transition: "The account cannot make this transition from its current status.",
    balance_not_zero: "The account still holds available balance.",
    open_reservations: "The account has open reservations.",
    pending_credits: "The account has pending credits.",
    invalid_query: "A query parameter is invalid.",
    account_not_active: "The source account may not send money.",
    insufficient_balance: "The source account has insufficient balance.",
    credit_not_allowed: "The account may not receive money.",
    idempotency_key_reused: "The Idempotency-Key was already used for another request."
  }

  # README, D14: a command that broke its input rules, with the messages for each field.
  def call(conn, {:error, {:validation_failed, fields}}) do
    conn
    |> put_status(:unprocessable_entity)
    |> put_view(json: AccountsWeb.ErrorJSON)
    |> render(:error, code: :validation_failed, detail: "The command is invalid.", fields: fields)
  end

  def call(conn, {:error, reason}) when is_map_key(@statuses, reason) do
    conn
    |> put_status(Map.fetch!(@statuses, reason))
    |> put_view(json: AccountsWeb.ErrorJSON)
    |> render(:error, code: reason, detail: Map.fetch!(@details, reason))
  end
end
