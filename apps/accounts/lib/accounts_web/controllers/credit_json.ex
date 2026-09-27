defmodule AccountsWeb.CreditJSON do
  def index(%{page: page}) do
    %{data: Enum.map(page.data, &data/1), next_cursor: page.next_cursor}
  end

  defp data(credit) do
    Map.take(credit, [:transfer_id, :amount, :status, :reason, :authorized_at, :settled_at])
  end
end
