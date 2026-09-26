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
    customer_id_required: :unprocessable_entity,
    reason_required: :unprocessable_entity,
    invalid_query: :unprocessable_entity,
    idempotency_key_required: :unprocessable_entity,
    invalid_destination: :unprocessable_entity,
    same_account: :unprocessable_entity,
    invalid_amount: :unprocessable_entity,
    account_not_active: :unprocessable_entity,
    insufficient_balance: :unprocessable_entity,
    credit_not_allowed: :unprocessable_entity
  }

  @details %{
    not_found: "Not Found",
    account_not_found: "The account does not exist.",
    invalid_transition: "The account cannot make this transition from its current status.",
    balance_not_zero: "The account still holds available balance.",
    open_reservations: "The account has open reservations.",
    pending_credits: "The account has pending credits.",
    customer_id_required: "A customer_id is required.",
    reason_required: "A reason is required.",
    invalid_query: "A query parameter is invalid.",
    idempotency_key_required: "An Idempotency-Key header is required.",
    invalid_destination: "The transfer needs a destination account.",
    same_account: "An account cannot transfer to itself.",
    invalid_amount: "The amount must be a positive integer number of cents.",
    account_not_active: "The source account may not send money.",
    insufficient_balance: "The source account has insufficient balance.",
    credit_not_allowed: "The account may not receive money."
  }

  def call(conn, {:error, reason}) when is_map_key(@statuses, reason) do
    conn
    |> put_status(Map.fetch!(@statuses, reason))
    |> put_view(json: AccountsWeb.ErrorJSON)
    |> render(:error, code: reason, detail: Map.fetch!(@details, reason))
  end
end
