defmodule Accounts.Messaging.RabbitMQPublisher do
  @moduledoc """
  RabbitMQ adapter of `Accounts.Messaging.Publisher` (README, D3 and D10).

  Messages go point to point to a queue the receiving service owns, through the default
  exchange. The command `type` and the `message_id` travel as AMQP properties and the body is
  the JSON payload, marked persistent.

  A publish returns `:ok` only once the broker took responsibility for the message:

    * publisher confirms make the broker acknowledge every message;
    * `mandatory` makes it return a message no queue takes, e.g. before the Ledger declared
      its queue, and the publish fails with `{:error, :unroutable}`.

  Any failure lets the caller retry, so the outbox never loses a message. The process holds
  one connection and reconnects when it drops; while disconnected, publishing fails with
  `{:error, :not_connected}`.
  """

  @behaviour Accounts.Messaging.Publisher

  use GenServer

  require Logger

  @confirm_timeout :timer.seconds(5)
  @reconnect_delay :timer.seconds(2)

  def start_link(opts) do
    {name, opts} = Keyword.pop(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @impl Accounts.Messaging.Publisher
  def publish(message), do: publish(__MODULE__, message)

  def publish(server, message), do: GenServer.call(server, {:publish, message})

  @impl GenServer
  def init(opts) do
    config = Application.fetch_env!(:accounts, __MODULE__)

    state = %{
      url: Keyword.get(opts, :url, config[:url]),
      queue: Keyword.get(opts, :queue, config[:queue]),
      channel: nil
    }

    {:ok, state, {:continue, :connect}}
  end

  @impl GenServer
  def handle_continue(:connect, state), do: {:noreply, connect(state)}

  @impl GenServer
  def handle_info(:connect, state), do: {:noreply, connect(state)}

  def handle_info({:DOWN, _ref, :process, _pid, reason}, state) do
    Logger.warning("RabbitMQ connection lost: #{inspect(reason)}")
    {:noreply, schedule_reconnect(%{state | channel: nil})}
  end

  @impl GenServer
  def handle_call({:publish, _message}, _from, %{channel: nil} = state) do
    {:reply, {:error, :not_connected}, state}
  end

  def handle_call({:publish, message}, _from, state) do
    {:reply, do_publish(state, message), state}
  end

  defp connect(state) do
    with {:ok, connection} <- AMQP.Connection.open(state.url),
         {:ok, channel} <- AMQP.Channel.open(connection),
         :ok <- AMQP.Confirm.select(channel),
         :ok <- AMQP.Basic.return(channel, self()) do
      Process.monitor(connection.pid)
      %{state | channel: channel}
    else
      error ->
        Logger.warning("RabbitMQ connection failed: #{inspect(error)}")
        schedule_reconnect(state)
    end
  end

  defp schedule_reconnect(state) do
    Process.send_after(self(), :connect, @reconnect_delay)
    state
  end

  defp do_publish(state, message) do
    :ok =
      AMQP.Basic.publish(state.channel, "", state.queue, Jason.encode!(message.payload),
        message_id: message.message_id,
        type: message.type,
        content_type: "application/json",
        persistent: true,
        mandatory: true
      )

    if AMQP.Confirm.wait_for_confirms(state.channel, @confirm_timeout) == true do
      sync_returns(state.channel)
      if returned?(message.message_id), do: {:error, :unroutable}, else: :ok
    else
      {:error, :not_confirmed}
    end
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
