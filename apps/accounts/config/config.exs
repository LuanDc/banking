# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :accounts,
  ecto_repos: [Accounts.Repo],
  event_stores: [Accounts.EventStore],
  generators: [timestamp_type: :utc_datetime, binary_id: true]

# Commanded dispatches commands through Accounts.App, which reads and appends
# events with Accounts.EventStore.
config :accounts, Accounts.App,
  event_store: [
    adapter: Commanded.EventStore.Adapters.EventStore,
    event_store: Accounts.EventStore
  ]

# Messages to the Ledger go to the queue it owns, through RabbitMQ (README, D3 and D10).
config :accounts, Accounts.Messaging.Publisher, adapter: Accounts.Messaging.RabbitMQPublisher
config :accounts, Accounts.Messaging.RabbitMQPublisher, queue: "ledger.commands"

# The Ledger's events arrive on a queue Accounts owns, bound to the exchange the Ledger publishes
# to; a message that fails is dead-lettered instead of requeued (README, D3 and D10).
config :accounts, Accounts.Messaging.LedgerEventsConsumer,
  exchange: "ledger.events",
  routing_key: "ledger.batch.*",
  queue: "accounts.ledger-events",
  dead_letter_queue: "accounts.ledger-events.dead"

# Configures the endpoint
config :accounts, AccountsWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [json: AccountsWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Accounts.PubSub,
  live_view: [signing_salt: "Ua2B1h3B"]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# AccountsWeb.Telemetry polls the VM every second for the dashboard; the default poller would
# poll it a second time.
config :telemetry_poller, :default, false

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
