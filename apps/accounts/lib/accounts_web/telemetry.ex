defmodule AccountsWeb.Telemetry do
  @moduledoc """
  The metrics /dashboard charts (LiveDashboard). Besides Phoenix, Ecto and the VM, it charts
  what a load test pushes on: how busy the schedulers are, how long a query waits for a
  connection, how far the subscriptions to the event store lag, the messages waiting in the
  queues and the errors logged (`AccountsWeb.Telemetry.Sampler`, `AccountsWeb.Telemetry.ErrorCounter`).
  """

  use Supervisor
  import Telemetry.Metrics

  alias AccountsWeb.Telemetry.ErrorCounter
  alias AccountsWeb.Telemetry.Sampler

  def start_link(arg) do
    Supervisor.start_link(__MODULE__, arg, name: __MODULE__)
  end

  @impl true
  def init(_arg) do
    ErrorCounter.attach()

    children =
      [
        # Every second, so the dashboard follows a load test as it runs.
        {:telemetry_poller,
         measurements: [:memory, :total_run_queue_lengths], period: 1_000, init_delay: 1_000}
      ] ++ sampler()

    Supervisor.init(children, strategy: :one_for_one)
  end

  # Tests start their own.
  defp sampler do
    if Application.get_env(:accounts, :start_sampler, true), do: [Sampler], else: []
  end

  # LiveDashboard gives each metric name's first segment a tab: `accounts` holds what a load test
  # pushes on (the database pool, the subscriptions' lag, the queues and the errors), `vm` the
  # schedulers and memory.
  def metrics do
    [
      # Phoenix Metrics
      summary("phoenix.endpoint.stop.duration",
        unit: {:native, :millisecond}
      ),
      summary("phoenix.router_dispatch.stop.duration",
        tags: [:route],
        unit: {:native, :millisecond}
      ),
      counter("phoenix.router_dispatch.exception.duration",
        tags: [:route],
        description: "Requests that raised"
      ),

      # Database Metrics
      summary("accounts.repo.query.queue_time",
        unit: {:native, :millisecond},
        description:
          "The time spent waiting for a database connection: it grows once the pool is too small"
      ),
      summary("accounts.repo.query.query_time",
        unit: {:native, :millisecond},
        description: "The time spent executing the query"
      ),
      summary("accounts.repo.query.total_time",
        unit: {:native, :millisecond},
        description: "The sum of the other measurements"
      ),

      # Event Store Metrics
      last_value("accounts.subscription.lag.events",
        tags: [:subscription],
        description: "Events stored that the projector, the saga or the outbox has yet to handle"
      ),
      summary("commanded.application.dispatch.stop.duration",
        unit: {:native, :millisecond},
        description: "From dispatching a command to its events stored"
      ),
      summary("commanded.event.handle.stop.duration",
        tags: [:handler_name],
        unit: {:native, :millisecond}
      ),

      # RabbitMQ Metrics
      last_value("accounts.queue.messages", tags: [:queue], description: "Messages ready"),
      last_value("accounts.queue.consumers", tags: [:queue]),
      summary("broadway.processor.message.stop.duration",
        unit: {:native, :millisecond},
        description: "The time to handle one message from the Ledger's events queue"
      ),

      # Errors
      counter("accounts.error.count",
        tags: [:kind],
        description: "Errors logged, by the exception or the module that logged them"
      ),

      # VM Metrics
      last_value("vm.scheduler_utilization.total",
        description:
          "How busy the online schedulers are, in percent (100: the CPU quota is used up)"
      ),
      last_value("vm.total_run_queue_lengths.total"),
      last_value("vm.total_run_queue_lengths.cpu"),
      last_value("vm.total_run_queue_lengths.io"),
      last_value("vm.memory.total", unit: {:byte, :megabyte}),
      last_value("vm.memory.processes", unit: {:byte, :megabyte}),
      last_value("vm.memory.binary", unit: {:byte, :megabyte})
    ]
  end
end
