defmodule LedgerWeb.LedgerAccountJSON do
  def show(%{account: account}),
    do: Map.take(account, [:account_id, :status, :opened_at, :closed_at])

  def balance(%{balance: balance}) do
    Map.take(balance, [:account_id, :debit_total, :credit_total, :balance, :updated_at])
  end

  def entries(%{page: page}) do
    %{
      data: Enum.map(page.data, &entry/1),
      next_cursor: page.next_cursor
    }
  end

  def trial_balance(%{trial_balance: trial_balance}), do: trial_balance

  defp entry(entry) do
    Map.take(entry, [:batch_id, :correlation_id, :type, :amount, :booked_at])
  end
end
