defmodule Ledger.Messaging.RabbitMQPublisher do
  @moduledoc """
  RabbitMQ adapter of `Ledger.Messaging.Publisher` (README, D3 and D10).

  Events go to a durable topic exchange the Ledger owns and declares, under each message's
  `routing_key`; each subscriber binds a queue of its own. The event `type` and the `message_id`
  travel as AMQP properties and the body is the JSON payload, marked persistent.

  A publish returns `:ok` only once the broker took responsibility for the message:

    * publisher confirms make the broker acknowledge every message;
    * `mandatory` makes it return a message no queue takes, e.g. before the Ledger declared
      its queue, and the publish fails with `{:error, :unroutable}`.

  Every failure comes back as `{:error, reason}` and never as an exit, so the caller retries
  it like any other and the outbox never loses a message. The process holds one connection and
  one channel and reconnects when either drops. Meanwhile, publishing fails with
  `:not_connected`, `:channel_closed` (the channel died before this process noticed) or
  `:publisher_unavailable` (the process itself is down, restarting or too slow).
  """

  @behaviour Ledger.Messaging.Publisher

  use GenServer

  require Logger

  @confirm_timeout :timer.seconds(5)
  # Longer than the confirm timeout, so a publish waiting for its confirm still gets a reply.
  @call_timeout @confirm_timeout + :timer.seconds(5)
  @reconnect_delay :timer.seconds(2)

  def start_link(opts) do
    {name, opts} = Keyword.pop(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @impl Ledger.Messaging.Publisher
  def publish(message), do: publish(__MODULE__, message)

  # Never exits: a publisher that is down, restarting or too slow is one more transient
  # failure, and the caller's retry handles it like the others.
  def publish(server, message) do
    GenServer.call(server, {:publish, message}, @call_timeout)
  catch
    :exit, _reason -> {:error, :publisher_unavailable}
  end

  @impl GenServer
  def init(opts) do
    config = Application.fetch_env!(:ledger, __MODULE__)

    state = %{
      url: Keyword.get(opts, :url, config[:url]),
      exchange: Keyword.get(opts, :exchange, config[:exchange]),
      connection: nil,
      channel: nil
    }

    {:ok, state, {:continue, :connect}}
  end

  @impl GenServer
  def handle_continue(:connect, state), do: {:noreply, connect(state)}

  @impl GenServer
  def handle_info(:connect, state), do: {:noreply, connect(state)}

  # The channel or the connection went down. Whichever goes first starts a clean reconnect;
  # the other one's DOWN finds nothing left to do.
  def handle_info({:DOWN, _ref, :process, _pid, _reason}, %{channel: nil} = state) do
    {:noreply, state}
  end

  def handle_info({:DOWN, _ref, :process, _pid, reason}, state) do
    Logger.warning("RabbitMQ channel or connection lost: #{inspect(reason)}")
    close_connection(state.connection)
    {:noreply, schedule_reconnect(%{state | connection: nil, channel: nil})}
  end

  @impl GenServer
  def handle_call({:publish, _message}, _from, %{channel: nil} = state) do
    {:reply, {:error, :not_connected}, state}
  end

  def handle_call({:publish, message}, _from, state) do
    {:reply, do_publish(state, message), state}
  end

  defp connect(state) do
    # The AMQP client parses the URL's auth mechanisms with list_to_existing_atom/1, and the
    # atoms only exist once this module is loaded; in dev, modules load lazily.
    Code.ensure_loaded!(:amqp_auth_mechanisms)

    with {:ok, connection} <- AMQP.Connection.open(state.url),
         {:ok, channel} <- open_channel(connection, state.exchange) do
      Process.monitor(connection.pid)
      Process.monitor(channel.pid)
      %{state | connection: connection, channel: channel}
    else
      error ->
        Logger.warning("RabbitMQ connection failed: #{inspect(error)}")
        schedule_reconnect(state)
    end
  end

  defp open_channel(connection, exchange) do
    with {:ok, channel} <- AMQP.Channel.open(connection),
         :ok <- AMQP.Exchange.declare(channel, exchange, :topic, durable: true),
         :ok <- AMQP.Confirm.select(channel),
         :ok <- AMQP.Basic.return(channel, self()) do
      {:ok, channel}
    else
      error ->
        close_connection(connection)
        error
    end
  end

  defp close_connection(nil), do: :ok

  defp close_connection(connection) do
    AMQP.Connection.close(connection)
  catch
    :exit, _reason -> :ok
  end

  defp schedule_reconnect(state) do
    Process.send_after(self(), :connect, @reconnect_delay)
    state
  end

  # A channel can die before its DOWN reaches this process: talking to it then exits, which
  # becomes an error here instead of taking the publisher down.
  defp do_publish(state, message) do
    with :ok <- basic_publish(state, message),
         true <- AMQP.Confirm.wait_for_confirms(state.channel, @confirm_timeout) do
      sync_returns(state.channel)
      if returned?(message.message_id), do: {:error, :unroutable}, else: :ok
    else
      {:error, reason} -> {:error, reason}
      _not_confirmed -> {:error, :not_confirmed}
    end
  catch
    :exit, _reason -> {:error, :channel_closed}
  end

  defp basic_publish(state, message) do
    AMQP.Basic.publish(
      state.channel,
      state.exchange,
      message.routing_key,
      Jason.encode!(message.payload),
      message_id: message.message_id,
      type: message.type,
      content_type: "application/json",
      persistent: true,
      mandatory: true
    )
  end

  # The broker sends basic.return before the confirm, but the client forwards returns through
  # the channel's consumer process while the confirm comes from the channel itself, so the
  # return may still be on its way. A synchronous call to the consumer (registering this
  # process again as return handler) flushes it into the mailbox first.
  defp sync_returns(channel), do: :ok = AMQP.Basic.return(channel, self())

  defp returned?(message_id) do
    receive do
      {:basic_return, _payload, %{message_id: ^message_id}} -> true
    after
      0 -> false
    end
  end
end
