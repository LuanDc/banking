defmodule Ledger.Messaging.Publisher do
  @moduledoc """
  Port for publishing the Ledger's events to other services (README, D3). The adapter is
  configured under `config :ledger, Ledger.Messaging.Publisher, adapter: ...`: RabbitMQ in the
  running service, a Mox mock in tests.
  """

  @callback publish(message :: map()) :: :ok | {:error, term()}

  def publish(message), do: adapter().publish(message)

  defp adapter do
    :ledger
    |> Application.fetch_env!(__MODULE__)
    |> Keyword.fetch!(:adapter)
  end
end
