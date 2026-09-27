defmodule Accounts.Messaging.LedgerEventsConsumer do
  @moduledoc """
  Broadway pipeline consuming the Ledger's events (README, D3 and D10).

  Each message carries the event `type` as an AMQP property and its payload as a JSON body. The
  pipeline only adapts it for `Accounts.Messaging.LedgerEventsInbox`, which turns it into
  commands and dispatches them: a message is acknowledged once every command was taken.

  Accounts declares its own topology: a durable queue bound to the Ledger's topic exchange, whose
  rejected messages go to a dead-letter queue. It declares the exchange as well, so it can start
  before the Ledger. A message that fails — unknown event, invalid body, or a command an
  aggregate refuses — is rejected without requeue and dead-lettered, so it cannot loop and stays
  available to inspect and replay.
  """

  use Broadway

  alias Accounts.Lineage
  alias Accounts.Messaging.LedgerEventsInbox
  alias Broadway.Message

  def start_link(_opts) do
    # The AMQP client parses the URL's auth mechanisms with list_to_existing_atom/1, and the
    # atoms only exist once this module is loaded; in dev, modules load lazily.
    Code.ensure_loaded!(:amqp_auth_mechanisms)

    Broadway.start_link(__MODULE__,
      name: __MODULE__,
      producer: [module: producer(), concurrency: 1],
      processors: [default: [concurrency: 1]]
    )
  end

  @impl Broadway
  def handle_message(_processor, %Message{} = message, _context) do
    # README, D17: the commands join the message's conversation, caused by the message.
    lineage =
      message.metadata
      |> Lineage.from_message()
      |> Lineage.log()

    with {:ok, payload} <- decode(message.data),
         :ok <-
           LedgerEventsInbox.handle(
             %{"type" => message.metadata.type, "payload" => payload},
             lineage
           ) do
      message
    else
      {:error, reason} -> Message.failed(message, reason)
    end
  end

  defp decode(data) do
    case Jason.decode(data) do
      {:ok, payload} -> {:ok, payload}
      {:error, %Jason.DecodeError{}} -> {:error, :invalid_json}
    end
  end

  defp producer do
    config = Application.fetch_env!(:accounts, __MODULE__)
    Keyword.get_lazy(config, :producer, fn -> {BroadwayRabbitMQ.Producer, rabbitmq(config)} end)
  end

  defp rabbitmq(config) do
    exchange = Keyword.fetch!(config, :exchange)
    queue = Keyword.fetch!(config, :queue)
    dead_letter_queue = Keyword.fetch!(config, :dead_letter_queue)

    [
      queue: queue,
      connection: Keyword.fetch!(config, :url),
      after_connect: fn channel ->
        :ok = AMQP.Exchange.declare(channel, exchange, :topic, durable: true)
        {:ok, _} = AMQP.Queue.declare(channel, dead_letter_queue, durable: true)
        :ok
      end,
      declare: [
        durable: true,
        arguments: [
          {"x-dead-letter-exchange", :longstr, ""},
          {"x-dead-letter-routing-key", :longstr, dead_letter_queue}
        ]
      ],
      bindings: [{exchange, routing_key: Keyword.fetch!(config, :routing_key)}],
      metadata: [:type, :message_id, :correlation_id],
      on_success: :ack,
      on_failure: :reject
    ]
  end
end
