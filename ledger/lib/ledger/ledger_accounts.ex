defmodule Ledger.LedgerAccounts do
  @moduledoc """
  Entry point of the ledger accounts context, for the API.

  Only queries: the Ledger's commands arrive through RabbitMQ (README, D3 and D12). They read the
  read models (section 7 and D11), which are eventually consistent.
  """

  import Ecto.Query

  alias Ledger.Projections.AccountBalance
  alias Ledger.Projections.LedgerAccount
  alias Ledger.Projections.StatementEntry
  alias Ledger.Projections.TrialBalance
  alias Ledger.Repo

  @default_limit 50
  @max_limit 100

  def get_ledger_account(account_id) do
    case Repo.get(LedgerAccount, account_id) do
      nil -> {:error, :not_found}
      account -> {:ok, account}
    end
  end

  @doc "The account's debit and credit totals and balance, zero until something is booked."
  def get_balance(account_id) do
    with {:ok, account} <- get_ledger_account(account_id) do
      case Repo.get(AccountBalance, account.account_id) do
        nil ->
          {:ok,
           %AccountBalance{
             account_id: account.account_id,
             debit_total: 0,
             credit_total: 0,
             balance: 0
           }}

        balance ->
          {:ok, balance}
      end
    end
  end

  @doc """
  A page of the account's statement, newest first, booked from `"from"` and before `"to"`. Pass
  the page's `next_cursor` as `"after"` for the next one.
  """
  def list_entries(params) do
    with {:ok, account} <- get_ledger_account(params["account_id"]),
         {:ok, from} <- parse_datetime(params["from"]),
         {:ok, to} <- parse_datetime(params["to"]),
         {:ok, limit} <- parse_limit(params["limit"]),
         {:ok, after_id} <- parse_cursor(params["after"]) do
      entries =
        StatementEntry
        |> where(account_id: ^account.account_id)
        |> filter_from(from)
        |> filter_to(to)
        |> filter_after(after_id)
        |> order_by(desc: :id)
        |> limit(^(limit + 1))
        |> Repo.all()

      {:ok, to_page(entries, limit)}
    end
  end

  @doc "Every account's debits and credits, which are equal whenever the ledger is sound."
  def get_trial_balance do
    trial_balance = Repo.one!(TrialBalance)

    %{
      debit_total: trial_balance.debit_total,
      credit_total: trial_balance.credit_total,
      balanced: trial_balance.debit_total == trial_balance.credit_total
    }
  end

  defp filter_from(query, nil), do: query
  defp filter_from(query, from), do: where(query, [entry], entry.booked_at >= ^from)

  defp filter_to(query, nil), do: query
  defp filter_to(query, to), do: where(query, [entry], entry.booked_at < ^to)

  defp filter_after(query, nil), do: query
  defp filter_after(query, after_id), do: where(query, [entry], entry.id < ^after_id)

  # One row past the limit tells whether there is a next page.
  defp to_page(rows, limit) do
    {data, rest} = Enum.split(rows, limit)

    next_cursor =
      if rest == [] do
        nil
      else
        data
        |> List.last()
        |> Map.fetch!(:id)
        |> to_string()
      end

    %{data: data, next_cursor: next_cursor}
  end

  defp parse_datetime(nil), do: {:ok, nil}

  defp parse_datetime(string) do
    case DateTime.from_iso8601(string) do
      {:ok, datetime, _offset} -> {:ok, datetime}
      {:error, _reason} -> {:error, :invalid_query}
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
