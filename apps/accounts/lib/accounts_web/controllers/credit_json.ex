defmodule AccountsWeb.CreditJSON do
  def index(%{page: page}) do
    %{data: Enum.map(page.data, &data/1), next_cursor: page.next_cursor}
  end

  defp data(credit) do
    credit
    |> Map.take([:amount, :status, :reason, :authorized_at, :settled_at])
    |> Map.put(:correlation_id, credit.transfer_id)
  end
end
