defmodule Ledger.Messaging.CommandsConsumer do
  @moduledoc """
  Broadway pipeline consuming the command queue the Ledger owns (README, D3 and D10).

  Each message carries the command `type` as an AMQP property and its payload as a JSON body.
  The pipeline only adapts it for `Ledger.Messaging.Inbox`, which composes the command and
  dispatches it: a message is acknowledged once the aggregate took the command.

  The Ledger declares its own topology: a durable queue whose rejected messages go to a
  dead-letter queue. A message that fails — unknown command, invalid body, or a command the
  aggregate refuses — is rejected without requeue and dead-lettered, so it cannot loop and
  stays available to inspect and replay.

  A single processor keeps messages in order, so a CloseLedgerAccount is never handled before
  the OpenLedgerAccount of the same account.
  """

  use Broadway

  alias Broadway.Message
  alias Ledger.Lineage
  alias Ledger.Messaging.Inbox

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
    # README, D17: the command joins the message's conversation, caused by the message.
    lineage =
      message.metadata
      |> Lineage.from_message()
      |> Lineage.log()

    with {:ok, payload} <- decode(message.data),
         :ok <-
           Inbox.handle(%{"type" => message.metadata.type, "payload" => payload}, lineage) do
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
    config = Application.fetch_env!(:ledger, __MODULE__)
    Keyword.get_lazy(config, :producer, fn -> {BroadwayRabbitMQ.Producer, rabbitmq(config)} end)
  end

  defp rabbitmq(config) do
    dead_letter_queue = Keyword.fetch!(config, :dead_letter_queue)

    [
      queue: Keyword.fetch!(config, :queue),
      connection: Keyword.fetch!(config, :url),
      after_connect: fn channel ->
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
      metadata: [:type, :message_id, :correlation_id],
      on_success: :ack,
      on_failure: :reject
    ]
  end
end
