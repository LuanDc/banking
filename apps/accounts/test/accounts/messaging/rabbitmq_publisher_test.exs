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

  @message %{
    message_id: "evt-1",
    correlation_id: "corr-1",
    type: "OpenLedgerAccount",
    payload: %{account_id: "acc-1"}
  }

  test "publishes the message to the queue as persistent JSON", %{channel: channel, queue: queue} do
    {:ok, _} = AMQP.Queue.declare(channel, queue, exclusive: true)
    start_supervised!({RabbitMQPublisher, queue: queue, name: :test_publisher})

    assert :ok = RabbitMQPublisher.publish(:test_publisher, @message)

    assert {:ok, body, meta} = AMQP.Basic.get(channel, queue, no_ack: true)
    assert Jason.decode!(body) == %{"account_id" => "acc-1"}
    assert %{message_id: "evt-1", type: "OpenLedgerAccount", persistent: true} = meta
    # README, D17: the lineage travels as a property, never in the body.
    assert meta.correlation_id == "corr-1"
    assert meta.content_type == "application/json"
  end

  test "fails when no queue takes the message, so it is retried instead of lost", %{queue: queue} do
    start_supervised!({RabbitMQPublisher, queue: queue, name: :test_publisher})

    assert {:error, :unroutable} = RabbitMQPublisher.publish(:test_publisher, @message)
  end

  test "survives a closed channel and publishes again once reconnected", %{
    channel: channel,
    queue: queue
  } do
    {:ok, _} = AMQP.Queue.declare(channel, queue, exclusive: true)
    publisher = start_supervised!({RabbitMQPublisher, queue: queue, name: :test_publisher})

    :ok = AMQP.Channel.close(:sys.get_state(publisher).channel)

    assert {:error, _reason} = RabbitMQPublisher.publish(:test_publisher, @message)
    assert Process.alive?(publisher)
    assert eventually(fn -> RabbitMQPublisher.publish(:test_publisher, @message) == :ok end)
  end

  defp eventually(check, attempts \\ 50) do
    cond do
      check.() -> true
      attempts == 0 -> false
      true -> Process.sleep(100) && eventually(check, attempts - 1)
    end
  end

  @tag integration: false
  test "returns an error instead of exiting when the publisher is not running" do
    assert {:error, :publisher_unavailable} =
             RabbitMQPublisher.publish(:no_such_publisher, @message)
  end
end
