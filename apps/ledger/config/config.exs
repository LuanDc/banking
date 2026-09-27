# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :ledger,
  ecto_repos: [Ledger.Repo],
  event_stores: [Ledger.EventStore],
  generators: [timestamp_type: :utc_datetime, binary_id: true]

# Commanded dispatches commands through Ledger.App, which reads and appends
# events with Ledger.EventStore.
config :ledger, Ledger.App,
  event_store: [
    adapter: Commanded.EventStore.Adapters.EventStore,
    event_store: Ledger.EventStore
  ]

# Commands from other services arrive on the queue the Ledger owns; a message that fails is
# dead-lettered instead of requeued (README, D3 and D10).
config :ledger, Ledger.Messaging.CommandsConsumer,
  queue: "ledger.commands",
  dead_letter_queue: "ledger.commands.dead"

# The events other contexts need go out on a topic exchange the Ledger owns (README, D3).
config :ledger, Ledger.Messaging.Publisher, adapter: Ledger.Messaging.RabbitMQPublisher
config :ledger, Ledger.Messaging.RabbitMQPublisher, exchange: "ledger.events"

# Configures the endpoint
config :ledger, LedgerWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [json: LedgerWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Ledger.PubSub,
  live_view: [signing_salt: "pmN/Cm+3"]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id, :correlation_id]

# LedgerWeb.Telemetry polls the VM every second for the dashboard; the default poller would
# poll it a second time.
config :telemetry_poller, :default, false

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
