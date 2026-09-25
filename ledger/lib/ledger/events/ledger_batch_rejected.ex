defmodule Ledger.Events.LedgerBatchRejected do
  @moduledoc """
  A batch was rejected and nothing was booked. Triggers the compensation that releases the
  reservation in Account Management.
  """

  @derive Jason.Encoder
  defstruct [:batch_id, :correlation_id, :reason]

  defimpl Commanded.Serialization.JsonDecoder do
    # JSON has no atoms: the reason comes back from the event store as a string.
    def decode(%{reason: reason} = event), do: %{event | reason: String.to_existing_atom(reason)}
  end
end
