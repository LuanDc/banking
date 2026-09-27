defmodule AccountsWeb.Telemetry.SamplerTest do
  # Runs against the Postgres and RabbitMQ of docker-compose.yml.
  use ExUnit.Case, async: false

  @moduletag :integration

  alias AccountsWeb.Telemetry.Sampler

  @url Application.compile_env!(:accounts, [Accounts.Messaging.RabbitMQPublisher, :url])

  setup do
    ref = make_ref()
    test = self()

    :telemetry.attach_many(
      ref,
      [[:vm, :scheduler_utilization], [:accounts, :subscription, :lag], [:accounts, :queue]],
      fn event, measurements, metadata, _config ->
        send(test, {event, measurements, metadata})
      end,
      nil
    )

    on_exit(fn -> :telemetry.detach(ref) end)
  end

  test "samples how busy the schedulers are, in percent" do
    start_sampler(queues: [])

    assert_receive {[:vm, :scheduler_utilization], %{total: total}, %{}}, 2_000
    assert total >= 0 and total <= 100
  end

  test "samples how many events each subscription to the event store is behind" do
    # A subscription that has seen nothing yet, written the way EventStore keeps it.
    name = "sampler_test_#{System.unique_integer([:positive])}"

    Postgrex.query!(
      Accounts.EventStore.Postgrex,
      "INSERT INTO subscriptions (stream_uuid, subscription_name) VALUES ('$all', $1)",
      [name]
    )

    on_exit(fn ->
      Postgrex.query!(
        Accounts.EventStore.Postgrex,
        "DELETE FROM subscriptions WHERE subscription_name = $1",
        [name]
      )
    end)

    start_sampler(queues: [])

    assert_receive {[:accounts, :subscription, :lag], %{events: lag}, %{subscription: ^name}},
                   2_000

    assert lag >= 0
  end

  test "samples the messages waiting in each queue, and skips a queue that is missing" do
    # Not exclusive: the sampler reads it from a connection of its own.
    queue = "sampler-test-#{System.unique_integer([:positive])}"
    {:ok, connection} = AMQP.Connection.open(@url)
    {:ok, channel} = AMQP.Channel.open(connection)
    {:ok, _} = AMQP.Queue.declare(channel, queue, durable: true)

    on_exit(fn ->
      {:ok, connection} = AMQP.Connection.open(@url)
      {:ok, channel} = AMQP.Channel.open(connection)
      {:ok, _} = AMQP.Queue.delete(channel, queue)
      AMQP.Connection.close(connection)
    end)

    :ok = AMQP.Basic.publish(channel, "", queue, "one")
    :ok = AMQP.Basic.publish(channel, "", queue, "two")

    start_sampler(queues: ["sampler-test-missing", queue])

    assert_receive {[:accounts, :queue], %{messages: 2, consumers: 0}, %{queue: ^queue}}, 2_000
    refute_received {[:accounts, :queue], _, %{queue: "sampler-test-missing"}}
  end

  test "keeps sampling when the broker is unreachable" do
    start_sampler(url: "amqp://banking:banking@localhost:1", queues: ["accounts.ledger-events"])

    assert_receive {[:vm, :scheduler_utilization], _, _}, 2_000
    assert_receive {[:vm, :scheduler_utilization], _, _}, 2_000
    refute_received {[:accounts, :queue], _, _}
  end

  defp start_sampler(opts) do
    start_supervised!({Sampler, Keyword.merge([name: nil, url: @url, interval: 100], opts)})
  end
end
