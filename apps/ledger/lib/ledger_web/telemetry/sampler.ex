defmodule LedgerWeb.Telemetry.Sampler do
  @moduledoc """
  Samples, every second, what a load test watches on the dashboard and no telemetry event
  reports on its own:

    * `[:vm, :scheduler_utilization]` - how busy the online schedulers were since the last
      sample, in percent (`total`). The BEAM sets them from the container's CPU quota, so
      100 means the quota is used up;
    * `[:ledger, :subscription, :lag]` - `events` each subscription to the event store (the
      projectors and the outbox) has yet to handle, tagged by `subscription`;
    * `[:ledger, :queue]` - `messages` ready and `consumers` of each queue the Ledger owns,
      tagged by `queue`.

  A source that fails, such as the broker being down, is skipped for that sample, and the
  others go on.
  """

  use GenServer

  @interval :timer.seconds(1)

  # Commanded's handlers subscribe to the `$all` stream, whose version is the last event stored.
  @lag_query """
  SELECT s.subscription_name, a.stream_version - COALESCE(s.last_seen, 0)
  FROM subscriptions s
  JOIN streams a ON a.stream_uuid = s.stream_uuid
  WHERE s.stream_uuid = '$all'
  """

  # EventStore names its connection pool after the event store.
  @event_store_conn Ledger.EventStore.Postgrex

  def start_link(opts) do
    {name, opts} = Keyword.pop(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @impl GenServer
  def init(opts) do
    consumer = Application.fetch_env!(:ledger, Ledger.Messaging.CommandsConsumer)
    publisher = Application.fetch_env!(:ledger, Ledger.Messaging.RabbitMQPublisher)

    state = %{
      interval: Keyword.get(opts, :interval, @interval),
      url: Keyword.get_lazy(opts, :url, fn -> publisher[:url] end),
      queues:
        Keyword.get_lazy(opts, :queues, fn ->
          [consumer[:queue], consumer[:dead_letter_queue]]
        end),
      connection: nil,
      schedulers: nil
    }

    # Kept on for as long as this process lives.
    :erlang.system_flag(:scheduler_wall_time, true)
    send(self(), :sample)
    {:ok, %{state | schedulers: :scheduler.sample()}}
  end

  @impl GenServer
  def handle_info(:sample, state) do
    Process.send_after(self(), :sample, state.interval)

    state =
      state
      |> sample_schedulers()
      |> sample_queues()

    sample_lag()
    {:noreply, state}
  end

  def handle_info(_message, state), do: {:noreply, state}

  defp sample_schedulers(state) do
    sample = :scheduler.sample()
    utilization = :scheduler.utilization(state.schedulers, sample)
    {:total, total, _} = List.keyfind(utilization, :total, 0)

    :telemetry.execute([:vm, :scheduler_utilization], %{total: total * 100})

    %{state | schedulers: sample}
  end

  defp sample_lag do
    case query_lag() do
      {:ok, %{rows: rows}} ->
        for [subscription, lag] <- rows do
          :telemetry.execute([:ledger, :subscription, :lag], %{events: lag}, %{
            subscription: subscription
          })
        end

      {:error, _reason} ->
        :skipped
    end
  end

  defp query_lag do
    Postgrex.query(@event_store_conn, @lag_query, [])
  catch
    :exit, reason -> {:error, reason}
  end

  defp sample_queues(%{queues: []} = state), do: state

  defp sample_queues(state) do
    case connect(state) do
      {:ok, connection} ->
        Enum.each(state.queues, &sample_queue(connection, &1))
        %{state | connection: connection}

      :error ->
        %{state | connection: nil}
    end
  end

  defp connect(%{connection: %AMQP.Connection{pid: pid} = connection}) do
    if Process.alive?(pid), do: {:ok, connection}, else: :error
  end

  defp connect(%{url: url}) do
    case AMQP.Connection.open(url, name: "ledger dashboard sampler") do
      {:ok, connection} -> {:ok, connection}
      {:error, _reason} -> :error
    end
  end

  # A channel per queue: a missing queue makes the broker close the channel that asked for it.
  defp sample_queue(connection, queue) do
    with {:ok, channel} <- AMQP.Channel.open(connection) do
      case AMQP.Queue.status(channel, queue) do
        {:ok, %{message_count: messages, consumer_count: consumers}} ->
          :telemetry.execute([:ledger, :queue], %{messages: messages, consumers: consumers}, %{
            queue: queue
          })

          AMQP.Channel.close(channel)

        _missing ->
          :skipped
      end
    end
  catch
    :exit, _reason -> :skipped
  end
end
