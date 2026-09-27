defmodule AccountsWeb.Telemetry.ErrorCounter do
  @moduledoc """
  A `:logger` handler that turns every error log into a `[:accounts, :error]` telemetry event,
  so the dashboard counts the failures a load test causes next to the pool, the queues and the
  schedulers that may explain them.

  The `kind` tag is the exception that crashed (`DBConnection.ConnectionError`, a Postgrex or an
  AMQP error, ...) or, for an error logged without one, the module that logged it.
  """

  @doc "Adds the handler. It stays added across restarts of the telemetry supervisor."
  @spec attach() :: :ok
  def attach do
    case :logger.add_handler(__MODULE__, __MODULE__, %{level: :error}) do
      :ok -> :ok
      {:error, {:already_exist, __MODULE__}} -> :ok
    end
  end

  @doc false
  def log(%{meta: meta}, _config) do
    :telemetry.execute([:accounts, :error], %{count: 1}, %{kind: kind(meta)})
  end

  defp kind(%{crash_reason: {%{__exception__: true, __struct__: exception}, _stacktrace}}),
    do: inspect(exception)

  defp kind(%{crash_reason: {reason, _stacktrace}}) when is_atom(reason), do: inspect(reason)
  defp kind(%{mfa: {module, _function, _arity}}), do: inspect(module)
  defp kind(_meta), do: "other"
end
