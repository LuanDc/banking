defmodule Ledger.Lineage do
  @moduledoc """
  The message lineage every hop passes on (README, D17): the `correlation_id` of the
  conversation, and the `causation_id` of the message that caused the next one. It is metadata
  only: no rule reads it.
  """

  require Logger

  @doc "The dispatch options of a command caused by an event."
  def from_event(metadata) do
    present(correlation_id: metadata[:correlation_id], causation_id: metadata[:event_id])
  end

  @doc """
  The dispatch options of a command caused by a RabbitMQ message: its `correlation_id`
  property, and its `message_id`, the id of the event it was published from. The event store
  keeps both as UUIDs, so anything else is left out and Commanded starts a lineage of its own.
  """
  def from_message(metadata) do
    present(
      correlation_id: uuid(metadata[:correlation_id]),
      causation_id: uuid(metadata[:message_id])
    )
  end

  @doc "Tags this process's logs with the conversation, and returns the options unchanged."
  def log(options) do
    Logger.metadata(correlation_id: options[:correlation_id])
    options
  end

  defp present(options), do: Enum.reject(options, fn {_key, value} -> is_nil(value) end)

  defp uuid(value) when is_binary(value) do
    case Ecto.UUID.cast(value) do
      {:ok, uuid} -> uuid
      :error -> nil
    end
  end

  defp uuid(_value), do: nil
end
