defmodule Ledger.Handlers.ProjectorFailures do
  @moduledoc """
  What a projector does when it fails to project an event (README, D18).

    * An error of the infrastructure is retried for as long as it takes, since the event is
      valid and the database comes back. The subscription waits on the event meanwhile.
    * Any other error is a bug, and no retry fixes it: the projector stops, and past its
      restarts the application with it, so the release is rolled back instead of running on
      with a read model that skipped an event.
  """

  require Logger

  alias Commanded.Event.FailureContext

  @first_delay 100
  @max_delay :timer.seconds(30)

  def error({:error, reason}, _event, %FailureContext{context: context} = failure_context) do
    if infrastructure?(reason) do
      failures = Map.get(context, :failures, 0) + 1

      Logger.warning(
        "#{failure_context.handler_name} waits for the database, attempt #{failures}"
      )

      {:retry, delay(failures),
       %{failure_context | context: Map.put(context, :failures, failures)}}
    else
      {:stop, reason}
    end
  end

  @doc """
  Whether a retry can succeed once the database is back: the pool dropped the request or lost
  its connection, or Postgres refused it for a reason of its own (a connection, a resource or a
  shutdown, a statement timeout, a serialization failure or a deadlock).
  """
  def infrastructure?(%DBConnection.ConnectionError{}), do: true

  def infrastructure?(%Postgrex.Error{postgres: %{pg_code: pg_code}}) when is_binary(pg_code),
    do: String.starts_with?(pg_code, ["08", "53", "57", "40001", "40P01"])

  def infrastructure?(_reason), do: false

  # The exponent stops growing once the delay reached its ceiling.
  defp delay(failures), do: min(@first_delay * Integer.pow(2, min(failures - 1, 10)), @max_delay)
end
