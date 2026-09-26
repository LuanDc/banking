defmodule Accounts.Messaging.Publisher do
  @moduledoc """
  Port for sending messages to other services (README, D3). The adapter is configured under
  `config :accounts, Accounts.Messaging.Publisher, adapter: ...`: RabbitMQ in the running
  service, a Mox mock in tests.
  """

  @callback publish(message :: map()) :: :ok | {:error, term()}

  def publish(message), do: adapter().publish(message)

  defp adapter do
    :accounts
    |> Application.fetch_env!(__MODULE__)
    |> Keyword.fetch!(:adapter)
  end
end
