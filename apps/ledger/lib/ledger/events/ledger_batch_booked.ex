defmodule Ledger.Events.LedgerBatchBooked do
  @moduledoc """
  A batch of ledger entries was booked. Booked entries are immutable.
  """

  @derive Jason.Encoder
  defstruct [:batch_id, :transfer_id, :entries]

  defimpl Commanded.Serialization.JsonDecoder do
    alias Ledger.LedgerEntry

    # The entries come back from the event store as plain maps, with the type as a string.
    def decode(%{entries: entries} = event) do
      %{event | entries: Enum.map(entries, &to_entry/1)}
    end

    defp to_entry(%{type: type} = entry) do
      struct(LedgerEntry, %{entry | type: String.to_existing_atom(type)})
    end
  end
end
