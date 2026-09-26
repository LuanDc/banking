defmodule Ledger.Events.LedgerBatchRejected do
  @moduledoc """
  A batch was rejected and nothing was booked. Triggers the compensation that releases the
  reservation in Account Management; the entries it would have booked tell whom to compensate.
  """

  @derive Jason.Encoder
  defstruct [:batch_id, :correlation_id, :reason, entries: []]

  defimpl Commanded.Serialization.JsonDecoder do
    alias Ledger.LedgerEntry

    # JSON has no atoms: the reason and the entry types come back from the event store as
    # strings. Rejections stored before the entries were added have none.
    def decode(%{reason: reason} = event) do
      %{
        event
        | reason: String.to_existing_atom(reason),
          entries: Enum.map(event.entries || [], &to_entry/1)
      }
    end

    defp to_entry(%{type: type} = entry) do
      struct(LedgerEntry, %{entry | type: String.to_existing_atom(type)})
    end
  end
end
