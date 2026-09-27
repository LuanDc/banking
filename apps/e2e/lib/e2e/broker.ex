defmodule E2E.Broker do
  @moduledoc """
  Publishes messages straight to RabbitMQ, as the services would, to replay them.

  Delivery between the services is at least once (docs, D3), so any message may arrive twice.
  A story publishes a copy of one that was already handled and checks that nothing moves
  (D4). The message shape mirrors the Ledger's contract: the `type` and a `message_id` as AMQP
  properties, and the payload as a persistent JSON body.
  """

  @commands_queue "ledger.commands"
  @events_exchange "ledger.events"

  @doc "Sends a command to the Ledger's queue, through the default exchange."
  @spec publish_command(String.t(), map()) :: :ok
  def publish_command(type, payload), do: publish("", @commands_queue, type, payload)

  @doc "Publishes a Ledger event on its topic exchange, e.g. under `ledger.batch.booked`."
  @spec publish_event(String.t(), String.t(), map()) :: :ok
  def publish_event(type, routing_key, payload),
    do: publish(@events_exchange, routing_key, type, payload)

  # Waits for the broker's confirm, so the message is queued before the story goes on.
  defp publish(exchange, routing_key, type, payload) do
    {:ok, connection} = AMQP.Connection.open(Application.fetch_env!(:e2e, :rabbitmq_url))

    try do
      {:ok, channel} = AMQP.Channel.open(connection)
      :ok = AMQP.Confirm.select(channel)

      :ok =
        AMQP.Basic.publish(channel, exchange, routing_key, Jason.encode!(payload),
          type: type,
          message_id: message_id(),
          content_type: "application/json",
          persistent: true,
          mandatory: true
        )

      true = AMQP.Confirm.wait_for_confirms(channel, 5_000)
      :ok
    after
      AMQP.Connection.close(connection)
    end
  end

  defp message_id, do: Base.encode16(:crypto.strong_rand_bytes(16), case: :lower)
end
