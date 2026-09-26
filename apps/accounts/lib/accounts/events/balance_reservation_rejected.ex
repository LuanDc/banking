defmodule Accounts.Events.BalanceReservationRejected do
  @moduledoc """
  A reservation was refused and nothing was held, e.g. for lack of available balance.
  """

  @derive Jason.Encoder
  defstruct [:account_id, :amount, :correlation_id, :reason, :to_account_id]

  defimpl Commanded.Serialization.JsonDecoder do
    # JSON has no atoms: the reason comes back from the event store as a string.
    def decode(%{reason: reason} = event), do: %{event | reason: String.to_existing_atom(reason)}
  end
end
