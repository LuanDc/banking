defmodule Ledger.Messaging.RabbitMQPublisherTest do
  # Runs against the RabbitMQ of docker-compose.yml. Each test publishes to an exchange of its
  # own, so it depends on nothing Accounts declares.
  use ExUnit.Case, async: false

  @moduletag :integration

  alias Ledger.Messaging.RabbitMQPublisher

  @url Application.compile_env!(:ledger, [RabbitMQPublisher, :url])

  setup do
    {:ok, connection} = AMQP.Connection.open(@url)
    {:ok, channel} = AMQP.Channel.open(connection)
    on_exit(fn -> AMQP.Connection.close(connection) end)

    %{channel: channel, exchange: "test.ledger.events.#{System.unique_integer([:positive])}"}
  end

  @message %{
    message_id: "evt-1",
    correlation_id: "corr-1",
    type: "LedgerBatchBooked",
    routing_key: "ledger.batch.booked",
    payload: %{batch_id: "batch-1"}
  }

  test "publishes the event to the topic exchange as persistent JSON", %{
    channel: channel,
    exchange: exchange
  } do
    publisher = start_supervised!({RabbitMQPublisher, exchange: exchange, name: :test_publisher})
    # The publisher declares the exchange once connected.
    assert eventually(fn -> :sys.get_state(publisher).channel != nil end)

    {:ok, %{queue: queue}} = AMQP.Queue.declare(channel, "", exclusive: true)
    :ok = AMQP.Queue.bind(channel, queue, exchange, routing_key: "ledger.batch.*")

    assert :ok = RabbitMQPublisher.publish(:test_publisher, @message)

    assert {:ok, body, meta} = AMQP.Basic.get(channel, queue, no_ack: true)
    assert Jason.decode!(body) == %{"batch_id" => "batch-1"}
    assert %{message_id: "evt-1", type: "LedgerBatchBooked", persistent: true} = meta
    # README, D17: the lineage travels as a property, never in the body.
    assert meta.correlation_id == "corr-1"
    assert meta.routing_key == "ledger.batch.booked"
  end

  test "fails when no queue is bound, so the event is retried instead of lost", %{
    exchange: exchange
  } do
    publisher = start_supervised!({RabbitMQPublisher, exchange: exchange, name: :test_publisher})
    assert eventually(fn -> :sys.get_state(publisher).channel != nil end)

    assert {:error, :unroutable} = RabbitMQPublisher.publish(:test_publisher, @message)
  end

  @tag integration: false
  test "returns an error instead of exiting when the publisher is not running" do
    assert {:error, :publisher_unavailable} =
             RabbitMQPublisher.publish(:no_such_publisher, @message)
  end

  defp eventually(check, attempts \\ 50) do
    cond do
      check.() -> true
      attempts == 0 -> false
      true -> Process.sleep(100) && eventually(check, attempts - 1)
    end
  end
end
