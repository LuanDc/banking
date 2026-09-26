defmodule AccountsWeb.AccountJSON do
  alias Accounts.Projections.CustomerAccount
  alias Accounts.Projections.StatusChange

  def created(%{account: account}), do: account

  def index(%{accounts: accounts}), do: %{data: Enum.map(accounts, &data/1)}

  def show(%{account: account}), do: data(account)

  def status_history(%{changes: changes}), do: %{data: Enum.map(changes, &data/1)}

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

  def data(%StatusChange{} = change),
    do: Map.take(change, [:event, :status, :reason, :occurred_at])
end
