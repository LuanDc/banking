defmodule Accounts.CustomerAccounts do
  @moduledoc """
  Entry point of the customer accounts context, for the API.

  Commands are built here and dispatched to the `CustomerAccount` aggregate. Queries read the
  read models (README, section 7 and D11), which are eventually consistent: a query right after a
  command may not see it yet.
  """

  alias Accounts.App
  alias Accounts.BankAccounts
  alias Accounts.Commands.ActivateCustomerAccount
  alias Accounts.Commands.AuthorizeCredit
  alias Accounts.Commands.BlockCustomerAccount
  alias Accounts.Commands.CloseCustomerAccount
  alias Accounts.Commands.FreezeCustomerAccount
  alias Accounts.Commands.OpenCustomerAccount
  alias Accounts.Commands.ReserveBalance
  alias Accounts.Commands.UnblockCustomerAccount
  alias Accounts.Commands.UnfreezeCustomerAccount
  import Ecto.Query

  alias Accounts.Events.BalanceReservationRejected
  alias Accounts.Events.BalanceReserved
  alias Accounts.Events.CreditRejected
  alias Accounts.Projections.Credit
  alias Accounts.Projections.CustomerAccount
  alias Accounts.Projections.Reservation
  alias Accounts.Projections.StatusChange
  alias Accounts.Repo
  alias Commanded.Commands.ExecutionResult

  @default_limit 50
  @max_limit 100

  @doc "Opens an account for `params[\"customer_id\"]`, under a new id. It starts pending KYC."
  def open_customer_account(params) do
    command =
      params
      |> OpenCustomerAccount.new()
      |> OpenCustomerAccount.generate_uuid()

    with :ok <- App.dispatch(command) do
      {:ok, Map.take(command, [:account_id, :customer_id]) |> Map.put(:status, :pending_kyc)}
    end
  end

  @doc "Activates an account pending KYC."
  def activate_customer_account(params) do
    params
    |> ActivateCustomerAccount.new()
    |> App.dispatch()
  end

  @doc "Blocks an active account's outbound money, for `params[\"reason\"]`."
  def block_customer_account(params) do
    params
    |> BlockCustomerAccount.new()
    |> App.dispatch()
  end

  @doc "Unblocks a blocked account."
  def unblock_customer_account(params) do
    params
    |> UnblockCustomerAccount.new()
    |> App.dispatch()
  end

  @doc "Freezes an active account, for `params[\"reason\"]`."
  def freeze_customer_account(params) do
    params
    |> FreezeCustomerAccount.new()
    |> App.dispatch()
  end

  @doc "Unfreezes a frozen account."
  def unfreeze_customer_account(params) do
    params
    |> UnfreezeCustomerAccount.new()
    |> App.dispatch()
  end

  @doc "Closes an empty account (README, D8)."
  def close_customer_account(params) do
    params
    |> CloseCustomerAccount.new()
    |> App.dispatch()
  end

  @doc """
  Starts a transfer by reserving `params[\"amount\"]` on `params[\"from_account_id\"]`
  for `params[\"to_account_id\"]` (README, section 5). The idempotency key is the saga's
  `transfer_id` (D4): a repeated key starts nothing new and returns the transfer as it stands.
  """
  def transfer_money(params, idempotency_key) do
    command =
      params
      |> Map.put("account_id", params["from_account_id"])
      |> Map.put("transfer_id", idempotency_key)
      |> ReserveBalance.new()

    case dispatch_for_events(command) do
      {:ok, [%BalanceReserved{}]} -> {:ok, pending_transfer(command)}
      {:ok, [%BalanceReservationRejected{reason: reason}]} -> {:error, reason}
      {:ok, []} -> current_transfer(command)
      {:error, _reason} = error -> error
    end
  end

  @doc """
  Receives an inbound PIX of `params[\"amount\"]` into `params[\"account_id\"]`: a credit
  from the bank's PIX settlement account (README, D2), authorized like any other. The idempotency
  key is its `transfer_id` (D4): a repeated key credits nothing twice.
  """
  def deposit(params, idempotency_key) do
    command =
      params
      |> Map.put("transfer_id", idempotency_key)
      |> Map.put("from_account_id", BankAccounts.pix_settlement())
      |> AuthorizeCredit.new()

    case dispatch_for_events(command) do
      {:ok, [%CreditRejected{reason: reason}]} ->
        {:error, reason}

      {:ok, _authorized_or_repeated} ->
        {:ok,
         %{
           correlation_id: command.transfer_id,
           account_id: command.account_id,
           amount: command.amount
         }}

      {:error, _reason} = error ->
        error
    end
  end

  def get_customer_account(account_id) do
    case Repo.get(CustomerAccount, account_id) do
      nil -> {:error, :not_found}
      account -> {:ok, account}
    end
  end

  def list_customer_accounts(%{"customer_id" => customer_id})
      when is_binary(customer_id) and customer_id != "" do
    accounts =
      CustomerAccount
      |> where(customer_id: ^customer_id)
      |> order_by(:opened_at)
      |> Repo.all()

    {:ok, accounts}
  end

  def list_customer_accounts(_params), do: {:error, :invalid_query}

  @doc "The account's FSM history, oldest first."
  def list_status_changes(account_id) do
    with {:ok, _account} <- get_customer_account(account_id) do
      changes =
        StatusChange
        |> where(account_id: ^account_id)
        |> order_by(:id)
        |> Repo.all()

      {:ok, changes}
    end
  end

  @doc """
  A page of the account's reservations, newest first, optionally of one `"status"`. Pass the
  page's `next_cursor` as `"after"` for the next one.
  """
  def list_reservations(params), do: list_page(Reservation, params)

  @doc "A page of the account's credits, like `list_reservations/1`."
  def list_credits(params), do: list_page(Credit, params)

  @doc """
  A transfer as it stands, read from its reservation and its credit (README, section 5):
  `pending` while the reservation is open, `completed` once confirmed, `failed` once rejected or
  released.
  """
  def get_transfer(transfer_id) do
    reservation =
      Reservation
      |> where(transfer_id: ^transfer_id)
      |> Repo.one()

    case reservation do
      nil ->
        {:error, :not_found}

      reservation ->
        credit =
          Credit
          |> where(
            transfer_id: ^transfer_id,
            account_id: ^(reservation.to_account_id || "")
          )
          |> Repo.one()

        {:ok,
         %{
           correlation_id: reservation.transfer_id,
           from_account_id: reservation.account_id,
           to_account_id: reservation.to_account_id,
           amount: reservation.amount,
           status: transfer_status(reservation.status),
           reason: failure_reason(reservation, credit)
         }}
    end
  end

  # The events a command caused, to answer with its decision: a rejection is an event too.
  defp dispatch_for_events(command) do
    with {:ok, %ExecutionResult{events: events}} <-
           App.dispatch(command, returning: :execution_result) do
      {:ok, events}
    end
  end

  # The read model may not show the first request yet.
  defp current_transfer(command) do
    case get_transfer(command.transfer_id) do
      {:error, :not_found} -> {:ok, pending_transfer(command)}
      found -> found
    end
  end

  defp pending_transfer(command) do
    %{
      correlation_id: command.transfer_id,
      from_account_id: command.account_id,
      to_account_id: command.to_account_id,
      amount: command.amount,
      status: :pending,
      reason: nil
    }
  end

  defp transfer_status(:open), do: :pending
  defp transfer_status(:confirmed), do: :completed
  defp transfer_status(_released_or_rejected), do: :failed

  defp failure_reason(%Reservation{status: :rejected, reason: reason}, _credit), do: reason

  defp failure_reason(%Reservation{status: :released}, %Credit{status: :rejected} = credit),
    do: credit.reason

  defp failure_reason(%Reservation{status: :released}, %Credit{status: :cancelled}),
    do: "batch_rejected"

  defp failure_reason(_reservation, _credit), do: nil

  defp list_page(schema, params) do
    with {:ok, account} <- get_customer_account(params["account_id"]),
         {:ok, status} <- parse_status(schema, params["status"]),
         {:ok, limit} <- parse_limit(params["limit"]),
         {:ok, after_id} <- parse_cursor(params["after"]) do
      rows =
        schema
        |> where(account_id: ^account.account_id)
        |> filter_status(status)
        |> filter_after(after_id)
        |> order_by(desc: :id)
        |> limit(^(limit + 1))
        |> Repo.all()

      {:ok, to_page(rows, limit)}
    end
  end

  defp filter_status(query, nil), do: query
  defp filter_status(query, status), do: where(query, status: ^status)

  defp filter_after(query, nil), do: query
  defp filter_after(query, after_id), do: where(query, [row], row.id < ^after_id)

  # One row past the limit tells whether there is a next page.
  defp to_page(rows, limit) do
    {data, rest} = Enum.split(rows, limit)

    next_cursor =
      if rest == [], do: nil, else: data |> List.last() |> Map.fetch!(:id) |> to_string()

    %{data: data, next_cursor: next_cursor}
  end

  defp parse_status(_schema, nil), do: {:ok, nil}

  defp parse_status(schema, status) do
    case Enum.find(Ecto.Enum.mappings(schema, :status), fn {_atom, string} -> string == status end) do
      {atom, _string} -> {:ok, atom}
      nil -> {:error, :invalid_query}
    end
  end

  defp parse_limit(nil), do: {:ok, @default_limit}
  defp parse_limit(limit), do: parse_integer(limit, 1..@max_limit)

  defp parse_cursor(nil), do: {:ok, nil}
  defp parse_cursor(cursor), do: parse_integer(cursor, 1..9_223_372_036_854_775_807)

  defp parse_integer(string, range) do
    case Integer.parse(string) do
      {integer, ""} -> if integer in range, do: {:ok, integer}, else: {:error, :invalid_query}
      _invalid -> {:error, :invalid_query}
    end
  end
end
