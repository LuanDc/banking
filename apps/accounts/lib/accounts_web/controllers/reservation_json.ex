defmodule AccountsWeb.ReservationJSON do
  def index(%{page: page}) do
    %{data: Enum.map(page.data, &data/1), next_cursor: page.next_cursor}
  end

  defp data(reservation) do
    reservation
    |> Map.take([:amount, :status, :reason, :reserved_at, :settled_at])
    |> Map.put(:correlation_id, reservation.transfer_id)
  end
end
