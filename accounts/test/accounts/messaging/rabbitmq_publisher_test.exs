defmodule Accounts.Messaging.RabbitMQPublisherTest do
  # Runs against the RabbitMQ of docker-compose.yml. Each test publishes to a queue of its own,
  # so it depends on nothing the Ledger declares.
  use ExUnit.Case, async: false

  @moduletag :integration

  alias Accounts.Messaging.RabbitMQPublisher

  @url Application.compile_env!(:accounts, [RabbitMQPublisher, :url])

  setup do
    {:ok, connection} = AMQP.Connection.open(@url)
    {:ok, channel} = AMQP.Channel.open(connection)
    on_exit(fn -> AMQP.Connection.close(connection) end)

    %{channel: channel, queue: "test.ledger.commands.#{System.unique_integer([:positive])}"}
  end

  @message %{message_id: "evt-1", type: "OpenLedgerAccount", payload: %{account_id: "acc-1"}}

  test "publishes the message to the queue as persistent JSON", %{channel: channel, queue: queue} do
    {:ok, _} = AMQP.Queue.declare(channel, queue, exclusive: true)
    start_supervised!({RabbitMQPublisher, queue: queue, name: :test_publisher})

    assert :ok = RabbitMQPublisher.publish(:test_publisher, @message)

    assert {:ok, body, meta} = AMQP.Basic.get(channel, queue, no_ack: true)
    assert Jason.decode!(body) == %{"account_id" => "acc-1"}
    assert %{message_id: "evt-1", type: "OpenLedgerAccount", persistent: true} = meta
    assert meta.content_type == "application/json"
  end

  test "fails when no queue takes the message, so it is retried instead of lost", %{queue: queue} do
    start_supervised!({RabbitMQPublisher, queue: queue, name: :test_publisher})

    assert {:error, :unroutable} = RabbitMQPublisher.publish(:test_publisher, @message)
  end
end
