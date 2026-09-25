defmodule AccountsWeb.AccountJSON do
  alias Accounts.Projections.CustomerAccount

  def created(%{account: account}), do: account

  def show(%{account: account}), do: data(account)

  def data(%CustomerAccount{} = account) do
    Map.take(account, [
      :account_id,
      :customer_id,
      :status,
      :status_reason,
      :available_balance,
      :opened_at,
      :closed_at,
      :updated_at
    ])
  end
end
