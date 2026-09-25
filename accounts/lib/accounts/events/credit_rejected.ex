defmodule Accounts.Events.CreditRejected do
  @moduledoc """
  The destination account may not receive the amount: the transfer is not booked and the source
  reservation is released.
  """

  @derive Jason.Encoder
  defstruct [:account_id, :amount, :correlation_id, :reason]

  defimpl Commanded.Serialization.JsonDecoder do
    # JSON has no atoms: the reason comes back from the event store as a string.
    def decode(%{reason: reason} = event), do: %{event | reason: String.to_existing_atom(reason)}
  end
end
