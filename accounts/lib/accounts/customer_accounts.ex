defmodule Accounts.CustomerAccounts do
  @moduledoc """
  Entry point of the customer accounts context, for the API.

  Commands are built here and dispatched to the `CustomerAccount` aggregate. Queries read the
  read models (README, section 7 and D11), which are eventually consistent: a query right after a
  command may not see it yet.
  """

  alias Accounts.Projections.CustomerAccount
  alias Accounts.Repo

  def get_customer_account(account_id) do
    case Repo.get(CustomerAccount, account_id) do
      nil -> {:error, :not_found}
      account -> {:ok, account}
    end
  end
end
