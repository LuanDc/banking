defmodule Accounts.CustomerAccounts do
  @moduledoc """
  Entry point of the customer accounts context, for the API.

  Commands are built here and dispatched to the `CustomerAccount` aggregate. Queries read the
  read models (README, section 7 and D11), which are eventually consistent: a query right after a
  command may not see it yet.
  """

  alias Accounts.App
  alias Accounts.Commands.ActivateCustomerAccount
  alias Accounts.Commands.BlockCustomerAccount
  alias Accounts.Commands.CloseCustomerAccount
  alias Accounts.Commands.FreezeCustomerAccount
  alias Accounts.Commands.OpenCustomerAccount
  alias Accounts.Commands.UnblockCustomerAccount
  alias Accounts.Commands.UnfreezeCustomerAccount
  import Ecto.Query

  alias Accounts.Projections.Credit
  alias Accounts.Projections.CustomerAccount
  alias Accounts.Projections.Reservation
  alias Accounts.Projections.StatusChange
  alias Accounts.Repo

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

  def list_customer_accounts(_params), do: {:error, :customer_id_required}

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
