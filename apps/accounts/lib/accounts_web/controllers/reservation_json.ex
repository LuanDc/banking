defmodule AccountsWeb.ReservationJSON do
  def index(%{page: page}) do
    %{data: Enum.map(page.data, &data/1), next_cursor: page.next_cursor}
  end

  defp data(reservation) do
    Map.take(reservation, [:correlation_id, :amount, :status, :reason, :reserved_at, :settled_at])
  end
end
