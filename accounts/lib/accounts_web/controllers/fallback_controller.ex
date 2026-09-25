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
    reason_required: :unprocessable_entity
  }

  @details %{
    not_found: "Not Found",
    account_not_found: "The account does not exist.",
    invalid_transition: "The account cannot make this transition from its current status.",
    balance_not_zero: "The account still holds available balance.",
    open_reservations: "The account has open reservations.",
    pending_credits: "The account has pending credits.",
    customer_id_required: "A customer_id is required.",
    reason_required: "A reason is required."
  }

  def call(conn, {:error, reason}) when is_map_key(@statuses, reason) do
    conn
    |> put_status(Map.fetch!(@statuses, reason))
    |> put_view(json: AccountsWeb.ErrorJSON)
    |> render(:error, code: reason, detail: Map.fetch!(@details, reason))
  end
end
